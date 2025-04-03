#!/usr/bin/env python3.13

import json
import os
import shutil

import markdownify
import playwright.sync_api
import requests

os_names: list[str] = [
	"iOS & iPadOS",
	"macOS",
	"Safari",
	"tvOS",
	"visionOS",
	"watchOS",
	"Xcode",
]

def fetch_release_notes_json(os_name: str) -> dict:
	response = requests.get(f"https://developer.apple.com/tutorials/data/documentation/{os_name.lower().replace(" & ", "-")}-release-notes.json")
	if response.status_code != 200:
		raise Exception(f"Failed to fetch {response.url}, status code: {response.status_code}")
	return json.loads(response.text)

def get_version_number(identifier: str) -> str:
	path_end: str = identifier.split("/")[-1]
	path_end = path_end.replace("release_notes", "release-notes")
	path_end = path_end.replace("mojave_", "mojave-")
	path_end = path_end.replace("visionos-release-notes", "visionos-1_0-release-notes")
	if path_end == "ios-16-release-notes": return "16.0.0 iOS"
	if path_end == "ipados-16-release-notes": return "16.0.0 iPadOS"
	if path_end == "macos-big-sur-11_0_1-universal-apps-release-notes": return "11.0.1 Universal Apps"
	if path_end == "macos-big-sur-11_0_1-ios-ipados-apps-on-mac-release-notes": return "11.0.1 iOS & iPadOS Apps on Mac"
	version_number: str = path_end.split("-")[-3].replace("_", ".")
	while len(version_number.split(".")) < 3:
		version_number += ".0"
	return version_number

def fetch_html(identifier: str) -> str:
	with playwright.sync_api.sync_playwright() as playwright_context_manager:
		with playwright_context_manager.webkit.launch() as browser:
			with browser.new_page() as page:
				page.goto(
					f"https://developer.apple.com/documentation/{identifier.split("/documentation/")[1].lower()}",
					wait_until="networkidle",
				)
				return page.inner_html(selector="#app-main")

def convert_to_markdown(html: str) -> str:
	return markdownify.markdownify(
		html=html,
		bullets="-",
		heading_style="ATX",
	)

for os_name in os_names:

	if os.path.exists(os_name):
		shutil.rmtree(os_name)
	os.mkdir(os_name)

	data: dict = fetch_release_notes_json(os_name=os_name)

	for section in data["topicSections"]:

		if section["title"] == "Articles": continue

		for identifier in section["identifiers"]:

			version_number: str = get_version_number(identifier=identifier)
			print(f"Fetching {os_name} {version_number} ...")
			html: str = fetch_html(identifier=identifier)
			html = html.replace("href=\"/documentation/", "href=\"https://developer.apple.com/documentation/")
			markdown: str = convert_to_markdown(html=html)
			markdown = markdown.split("\n## [See Also]")[0]
			with open(f"{os_name}/{version_number}.md", mode="w") as file:
				file.write(markdown)

#!/usr/bin/python3

import json
import logging
import os
import sys

# sudo pip3 install slackclient
from slack import WebClient
from slack.errors import SlackApiError

logging.basicConfig(level=logging.DEBUG)

slack_token = os.environ["SLACK_KEY"]
client = WebClient(token=slack_token)

if len(sys.argv) < 2:
    print(
        'usage: cat message.txt | '
        'SLACK_KEY=integration_key python slack_message.py '
        '[channel] [sender_name] [icon_emoji]'
    )

channel = sys.argv[1]
username = sys.argv[2].strip('"')
icon_emoji = sys.argv[3].strip(':')
text = sys.stdin.read()
blocks = None
try:
    blocks = json.loads(text)
    text = None
except json.decoder.JSONDecodeError:
    pass

try:
    response = client.chat_postMessage(
        icon_emoji=":" + icon_emoji + ":",
        username=username,
        channel=channel,
        text=text,
        blocks=blocks,
        type="mrkdwn",
        unfurl_links=False
    )
except SlackApiError as e:
    # You will get a SlackApiError if "ok" is False
    assert e.response["error"]  # str like 'invalid_auth', 'channel_not_found'

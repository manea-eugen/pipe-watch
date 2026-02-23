# PipeWatch

A native macOS menu bar app that monitors your GitLab pipelines and sends notifications when they complete.

## Install

Download the latest `.zip` from [Releases](https://github.com/manea-eugen/pipe-watch/releases), unzip, and right-click > **Open** to bypass Gatekeeper.

Requires macOS 14+.

## Setup

1. Create a GitLab [Personal Access Token](https://docs.gitlab.com/ee/user/profile/personal_access_tokens.html) with `read_api` scope
2. Launch PipeWatch — it lives in the menu bar
3. Open **Settings** (gear icon), paste your token and GitLab URL, click **Save & Reconnect**

## Build from source

```bash
brew install xcodegen
git clone https://github.com/manea-eugen/pipe-watch.git
cd pipe-watch
./build.sh Debug --run
```

## License

[Unlicense](LICENSE)

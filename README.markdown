**UPDATE**: to avoid conflict with Interface Builder hotkeys are changed to `Control -` and `Control +`.

# Customizing shortcuts

1. Open Keyboard Shortcuts in System Preferences.app
2. Click "+" under "App Shortcuts"
3. Choose Xcode.app
4. Type "Increase" under Menu Title
5. Type in desired hotkey, for example `⌘ =` for command + plus
6. Click "Add"
7. Repeat 2 - 6 for "Decrease" menu title

<img width="668" alt="screen shot 2016-06-10 at 10 32 32 pm" src="https://cloud.githubusercontent.com/assets/117041/15964393/ade650ee-2f5b-11e6-9bf4-87a1ebe8ddcf.png">
Thanks [@agentk](https://github.com/agentk) for the idea!


# AdjustFontSize

![screenshot](https://raw.github.com/zats/AdjustFontSize-Xcode-Plugin/master/README/xcode.png)

A simple plugin for Xcode to adjust font size without going into `Settings` → `Fonts & Colors` and changing each source type.

Simply hit `⌃ =` or `⌃ -` and all fonts will be adjusted. Plugin respects different font sizes per each syntax type.

**NOTE** keep in mind that it modifies the current theme file.

## Installation:

Install via [Alcatraz](https://github.com/alcatraz/Alcatraz).

OR

Clone this repo, Build and restart Xcode.

## Troubleshooting

If you do not see the plugin menu anymore, most likely it means that you;ve updated Xcode and have an old version of the plugin. Simply re-install the plugin through Alcatraz or by cloning and building the repository.

If it didn't help, please open an issue.

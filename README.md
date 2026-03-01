# nativebar

## About

Native MacOS application bar using [ghostty's](https://github.com/ghostty-org/ghostty/) custom [titlebar](https://ghostty.org/docs/config/reference#macos-titlebar-style), enabling the use of native tab bars without a persisted titlebar. I just added some hooks into MacOS.

> [!NOTE]
> This is unfinished & is my first AppKit/Swift project

## Build

```bash
 > ./build.sh 
 > ./run.sh 
```

or 

```bash
 > ./dev.sh 
```

## TODO


[ ] nativebar focused/unfocused unified styling 

[ ] focus referenced application after all interactions with nativebar e.g. drag & drop  

[ ] referenced applications not activating under certain state 

[ ] prevent dragging/resizing of nativebar

[ ] user derived config i.e. port derived config from ghostty

[ ] single tab to use tab bar instead of title bar e.g. [x post](https://x.com/mayfer/status/2024298589107966399?s=20)

[ ] tabbar initializes without clicking on appliaction icon 

[ ] more macos version support (i.e. bring over more ghossty functionality)

[ ] support for hooks into window managers (e.g. aerospace)

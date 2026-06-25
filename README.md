# APOD Linux Daily

A script that downloads the astronomy picture of the day (also known as [APOD](https://apod.nasa.gov/apod/)) and sets it as the current desktop wallpaper in Linux.

## HOW IT WORKS
`chmod +x *.sh`

The script works by requesting the APOD API, extracting the location of the HD version of the daily picture from that, and downloading it. The downloaded picture will then be set as the wallpaper on every detected screen/monitor, and a desktop notification will be sent. After the image file has been set as the current wallpaper, it will be left in the `./tmp` directory (or the custom target directory passed as an argument). The script will clean up outdated images several days later.

You can edit your crontab file (`crontab -e` in the terminal) to make this script work automatically and periodically. For example:

```cron
0 12 * * * /home/username/APOD_Linux_Daily/apod_daily.sh
```

## REQUIREMENT
- Linux desktop environment (GNOME, KDE Plasma, XFCE, Cinnamon, MATE) or window manager (Sway, Hyprland, i3/bspwm with `feh` or `nitrogen`).
- `curl` for downloading files.
- A JSON parser command: `jq` (recommended), `python3`/`python`, or `node`.
- `notify-send` (optional, for desktop notifications).

## KNOWN ISSUE
These scripts work by grabbing the link to the big version of an image. However, sometimes the APOD page uses videos or animations instead of a JPEG picture; in those cases, the script will attempt to fall back to the video's thumbnail image (YouTube or Vimeo), or send a notification if no thumbnail can be resolved.


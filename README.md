<img width="2560" height="1440" alt="temp-github" src="https://github.com/user-attachments/assets/a54c721e-8562-4532-ad1e-de0c1b8d374d" />

# ae2Colony
A CC:Tweaked lua script that sends AE2 items to Minecolonies

I expect to abandon this script at some point, if you want to make upgrades/changes feel free to comment somewhere here on the Github. I'd like to see it!

## Original Design Idea
- Advanced Peripherals adds a cool in-game command "/advancedperipherals getHashItem" that returns an exact "fingerprint" of an item, enchants/ durability etc.

## Requirements
- Advanced Peripherals versions 0.7.51b, 0.7.55b are confirmed working. Other versions likely are missing features this script requires.
- Post bugs here on the issues page. I'm a hobby programmer so I welcome tips/suggestions as well!

## Setup
 ```wget https://raw.githubusercontent.com/toastonrye/ae2Colony/refs/heads/main/ae2Colony.lua```

0. Video guide, it's long but setup is in the first ~10 mins or so. https://www.youtube.com/watch?v=bRNkBSM9rm4
1. Script designed and tested in ATM10 v4.2, it requires several mods from that modpack. CC:Tweaked, Advanced Peripherals, Minecolonies, AE2.
3. You need to understand how AE2 autocrafting and Minecolonies works. This script is an aid, it can't do everything!

### Known Issues
- 0.7.55b is the best version to use as of July 19'25. 53b or 54b won't work at all.
- In Advanced Peripherals(AP) 0.7.51b, for the colony integrator, getRequests() seems to crash if a colonist is missing some tools/armour.
- If items don't seem to autocraft or hang, they maybe missing items. If it wants 100 chests but can only make 10, it won't make any!

### Tips
- By default c:foods tags is blacklisted, then I whitelist certain foods like minecraft:carrot or minecraft:beef for the Hospitals or Resturants to cook.
- Food, Tools, Armour should eventually be handled by the colonists. This script works best with just building blocks to get started!
- Same with enchanted gear, your colonists should make them. This script shouldn't export enchanted items..
- If something is weird, check the log file or read the script for comments/hints. It's easier to read in a text editor, don't try to read in game!

### Future Ideas?
- More robust AE2 autocrafting status feedback.
- Toggle to disable domum ornamenum logic? So colonists can do the work.
- Nicer monitor display

### Misc Helper Scripts
- Two scripts that generate a logfile of data for the me bridge and colony integrator. They maybe helpful for tracking weird issues...

# Videos
v0.3 Setup & Quirks https://www.youtube.com/watch?v=bRNkBSM9rm4 - July 12'2025

v0.1 Demo: https://www.youtube.com/watch?v=YkcoSeZRbsw (This video is old, script is much newer.)

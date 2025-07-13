<img width="2560" height="1440" alt="temp-github" src="https://github.com/user-attachments/assets/a54c721e-8562-4532-ad1e-de0c1b8d374d" />

# ae2Colony
A CC:Tweaked lua script that sends AE2 items to Minecolonies

I expect to abandon this script at some point, if you want to make upgrades/changes feel free to comment somewhere here on the Github. I'd like to see it!

# Original Design Idea
- Advanced Peripherals adds a cool in-game command "/advancedperipherals getHashItem" that returns an exact "fingerprint" of an item, enchants/ durability etc.
- Fingerprints seemed like a nice start to have AE2 export the exact item Minecolonies wanted.

# Setup
- wget https://raw.githubusercontent.com/toastonrye/ae2Colony/refs/heads/main/ae2Colony.lua
0. Video guide, it's long but setup is in the first ~10 mins or so. https://www.youtube.com/watch?v=bRNkBSM9rm4
1. This script was written while playing ATM10 v4.2, it requires several mods from that modpack. CC:Tweaked, Advanced Peripherals, Minecolonies, AE2.
2. The Advanced Peripherals(AP) mod goes through frequent updates, there is a significant chance this script won't work if the AP version isn't 0.7.51b
3. You need to understand how to setup AE2 autocrafting systems, and have a general idea how Minecolonies works.
4. I'm a hobby programmer, it's difficult for me to test for every scenario, but please let me know of any issues and I'll try to help!

# Known Issues
- In Advanced Peripherals(AP) 0.7.51b, for the colony integrator, getRequests() seems to crash if a colonist is missing some tools/armour.
- I've tried to prevent enchanted tools and armour from exporting. The script isn't designed to handle better tiers of gear. Manually give your colonists better gear.
- If items don't seem to autocraft or hang, they maybe missing items. If it wants 100 chests but can only make 10, it won't make any!

# Tips
- By default c:foods tags is blacklisted, then I whitelist certain foods like minecraft:carrot or minecraft:beef for the Hospitals or Resturants to cook.
- Food, Tools, Armour should eventually be handled by the colonists. This script works best with just building blocks to get started!
- If something is weird, check the log file or read the script for comments/hints. It's easier to read in a text editor, don't try to read in game!

# Future Features Maybe?
- I'd like more robost information feedback about AE2 autocrafting status.
- Add toggle to disable domum ornamenum logic, colonists can apparently craft blocks?
- I'd like to make a nicer monitor display

# Misc Helper Scripts
- Two scripts that generate a logfile of data for the me bridge and colony integrator. They maybe helpful for tracking weird issues...

# Videos
v0.3 Setup & Quirks https://www.youtube.com/watch?v=bRNkBSM9rm4 - July 12'2025

v0.1 Demo: https://www.youtube.com/watch?v=YkcoSeZRbsw (This video is old, script is much newer.)

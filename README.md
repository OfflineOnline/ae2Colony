# ae2Colony
A CC:Tweaked lua script that sends AE2 items to Minecolonies

At some point I'll probably abandon this script, so if you want to use it and make upgrades, go for it! Please send me a link so I can maybe use it in the future.

# Setup
1. This script was written while playing ATM10 v4.2, it requires several mods from that modpack. CC:Tweaked, Advanced Peripherals, Minecolonies, AE2.
2. The Advanced Peripherals(AP) mod goes through frequent updates, there is a significant chance this script won't work if the AP version isn't 0.7.51b
3. You need to understand how to setup AE2 autocrafting systems, and have a general idea how Minecolonies works.
4. I'm a hobby programmer, it's difficult for me to test for every scenario, but please let me know of any issues and I'll try to help!

# Known Issues
- In Advanced Peripherals(AP) 0.7.51b, for the colony integrator, getRequests() seems to crash if a colonist is missing some tools/armour.
- I've crudely tried to handle the error, but the AP mod dev knows and I believe it's been fixed fixed for newer AP versions
- I've tried to prevent enchanted tools and armour from exporting. The script isn't designed to handle better tiers of gear. Manually give your colonists better gear.
- If items don't seem to autocraft or hang, they maybe missing items. If it wants 100 chests but can only make 10, it won't make any!

# Tips
- By default c:foods tags is blacklisted, then we whitelist certain foods like minecraft:carrot or minecraft:beef for the Hospitals or Resturants to cook.
- Be careful with tag blacklists and item whitelists, it's possible to loose important info like Hospitals wanting carrots or potatoes for healing
- If something is weird, check the log file or read the script for comments/hints. It's easier to read in a text editor, don't try to read in game!

# Future Features Maybe?
- I need a second monitor that displays "raw" colonist.getRequests(). It's possible to miss important info like Hospitals wanting potatoes because c:foods is blacklisted.
- I'd like to make a nicer monitor display
- I'd like more robost information feedback about AE2 autocrafting status.

# Videos
v0.1 Demo: https://www.youtube.com/watch?v=YkcoSeZRbsw (This video is old, script is much newer.)

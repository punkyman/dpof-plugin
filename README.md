# dpof-plugin
A DPOF plugin for Shotwell 0.18

Once loaded, the plugin allows to prepare a usb key to print images on a DPOF compatible printer. This may require a usb key formatted in fat16 depending on your printer.

First select images, then choose Publish, and point to the path of the USB key. The plugin will erase the content of the USB key, and write the pictures and DPOF data on it. Then unplug the key, plug it to the printer, and the pictures should start going out.

The DPOF standard is a simple standard : it is composed of pictures, a MISC folder, and a AUTPRINT.MRK file that contains the instructions to print the pictures. What the plugin does is reproduce this schema on the disk based on the pictures selected in shotwell.

There is very little security on the folder selected in the plugin, it only checks if it's a folder in /media. Be careful, since it's gonna erase the content !

To trace loading by shotwell, execute with the following command line :
SHOTWELL_LOG=1 SHOTWELL_LOG_FILE=:console: shotwell

To compile, install the sources of shotwell, then run :
./configure --install-headers
./make
./install

Then in the plugin folder, run :
./make
./make install

The plugin will install in the user folder : ~/.gnome2/shotwell/plugins

Still looking for a way to enable a plugin by default; as of now, 

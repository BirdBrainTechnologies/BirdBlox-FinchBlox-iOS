# Hummingbird-iOS-Support

This repo is dedicated to providing iOS support to the Hummingbird Robot Kit. 
It contains a "Snap!" app that allows a Hummingbird with a BLE module to be programmed as well as a Demo app that acts as a remte controller for the Hummingbird.

Along with the Hummingbird support, this repo also contains a "Snap!" app that does not require a Hummingbird. This is simply to make programming in "Snap!" easier to do while on a mobile device.

Current Snap Features: 
+ Offline Snap. You need internet the first time you open the app in order to download the snap source. Checks for updates daily. 
+ Access iOS sensors 
+ iPad can be used as a server (to access sensor data or Hummingbird data) that a computer can connect to.
+ Record voice and use the recording in Snap!
+ Export projects as an xml file via email or as raw xml text that is copied to the clipboard
+ Can open xml files using the app (project xmls) or can input project as raw xml text


Hummingbird Specific features: 
+ Can rename Hummingbird BLE module
+ Indicator light to show that the Hummingbird is connected
+ Automatically attempts to reconnect to the the last Hummingbird connected when the connection is lost
+ Access all Hummingbird input and output ports

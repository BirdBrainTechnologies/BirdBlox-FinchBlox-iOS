# Hummingbird-iOS-Support

This repo is dedicated to providing iOS support to the Hummingbird Robot Kit.

This repo uses CocoaPods. Make sure that CocoaPods is installed on your computer and then type 'pod install' on the command line in the BirdBlox folder.

This repo depends on the HummingbirdDragAndDrop repo for the javascript frontend. When running in debug mode, the most recent frontend files (from the dev branch) will be automatically downloaded from GitHub. To compile a release version there are several steps you must follow:
1. Make sure that appender.py has been run since the last frontend change (run python appender.py on the command line if not)
2. Copy latest all.js, alliOS9.js, HummingbirdDragAndDrop.html, HummingbirdDragAndDropiOS9.html, and MyCSS.css into the Frontend folder. 
3. Copy the folders SoundClips and SoundsForUI with all the .wav files to be included in the release into the Frontend folder, and the folder Videos with the calibration videos.
4. Set DO.enabled = false;
5. Change the scheme to Birdblox-Release (create this scheme if necessary).


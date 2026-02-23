# Image Annotation Tool

Image Annotation Tool will be image annotation tools that supports exporting annotations in both YOLO TXT and Pascal VOC XML file formats that runs on macos. 

## Similar apps
    - https://github.com/HumanSignal/label-studio/
        - open source
        - web based
        - not macos native app
        - More fuctions and features than this app will have initially.
        - may be a source for reference and open source useful libararies
    - https://rectlabel.com/ 
        - macos native app
        - close source
        - costs money, closest direct competiting app.
        - sometimes buggy
        - slow
        
## Basic Functions 

    - open a directoy, 
        - which will appear in tree structre in the left side bar, with will replace "general" in the template, all call this "files", 
        - "more" in the side bar will become "unsaved annotation", and will list the files names of XML files pending saving. Clicking them will load that image, and the unsaved changes to the XML.
    - will display jpg/png images in main window, recusively, one at a time.
    - will load the files, if exsiting of the same name as the image of:
        - .xml : Pascal VOC XML, the xml is source of truth.
        - .txt : which is the YOLO TXT Fomrat, the txt format is generated from the XML. 
    - process the files as needed, getting tag (object) name from XML
        - place movable bounding boxes for each object, similar to ![Bounding Box mockup]("./bounding-box.png")
        - The solid table at the top is where the text for the object name/tag is placed.
    - Using cross hair point style, allow the user to click draw retanagles on top of the image
        - turn the bonding box into the ![Bounding Box mockup]("./bounding-box.png")
        - allow all the bounding boxes text areas to be clickable to change the next. 
    - save and update the XML files when moving from one image to the next.
    - space bar will autosave/update the xml, and move to next image, the arrow keys right/left, will move images without saving
    - at the top level of the directory openned create a "classes.txt", and each time a new object name is create, add it to classes, for the YOLO TXT class id mappings. 
    - in ToolbarItem(s) ... change these to left/right navigation buttons and a save icon, and have them do those functions. 


## Output 

Research best ways and libraries and apis to implement this.
Create an  `002-implement-stage-001.md`, as AI prompts for yourself and if needed multiple stages.
I will review the implementation stages, and we will interate over them, if needed, before actually implementing. 



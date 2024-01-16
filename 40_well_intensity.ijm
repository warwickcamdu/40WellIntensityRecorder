#@ File (label = "Input directory", style = "directory") input
#@ File (label = "Output directory", style = "directory") output
#@ int (label = "Well size (pixels)", default=52) well_size
#@ boolean (label= "Despeckle") despec


//close any open images and reset the roiManager to prevent errors
roiManager("reset");
close("*");


processFile(input,output);

function processFile(input, output) {
	
	//Load image sequence
	File.openSequence(input);
	title=getTitle();
	
	//Flip
	run("Flip Horizontally","stack");
	
	//Rotate
	run("Rotate 90 Degrees Right");
	
	//If despeckle option selected despeckle
	if (despec) {
		run("Despeckle", "stack");
	}
	
	//Set to measure centroid coordinates
	run("Set Measurements...", "centroid perimeter shape descriptors redirect=None decimal=9");
	
	//Merge stack
	run("Z Project...", "projection=Median");
	run("Duplicate...", "title=Z_median");
	
	//Blur for better particle detection and circularity
	run("Gaussian Blur...", "sigma=5");
	
	//Find particles
	setAutoThreshold("MaxEntropy dark no-reset");
	setOption("BlackBackground", true);
	run("Convert to Mask");
	run("Analyze Particles...", "size=500-8000 include add");
	
	num_found = nResults();
	print(nResults());
	for (i = 0; i < num_found; i++) {
	  v = getResult('Circ.', i);
      if (v >= 0.5) {
    	roiManager('select',i);
    	roiManager("add");
		}
  	}
  
  	roiManager("Select", Array.getSequence(num_found));
	roiManager("delete");
	close("Results");

	selectWindow("Z_median");
	num_rois=roiManager("count");
	print(num_rois + " wells found");
	
	
	//Sort centroids and draw circles so that final wells are labelled
	//in order top to bottom, left to right
	roiManager("Measure");
	Table.sort("X");
	selectWindow("Z_median");
	
	for (i = 0; i < 5; i++) {
		x=newArray(8);
		y=newArray(8);
		for (j = 0; j < 8; j++) {
    		x[j] = getResult('X', i*8+j);
    		y[j] = getResult('Y', i*8+j);
		}
		arr=Array.rankPositions(y);
		for (j = 0; j < 8; j++) {
			makeOval(x[arr[j]]-well_size/2,y[arr[j]]-well_size/2,well_size,well_size);
    		roiManager("add");
		}
	}
	
	// remove original well detections, leaving only circular well selections
	roiManager("Select", Array.getSequence(num_rois));
	roiManager("delete");
	
	// shift to original stack for brightness measurements
	selectWindow(title);
	close("\\Others");
	
	//Measure mean grey value for every well at every time point
	run("Set Measurements...", "mean redirect=None decimal=9");
   	roiManager("Multi Measure");
   	saveAs("Results", output+"/Results_Mean_"+title+".csv");
   	close("Results");
	print("Saving mean measurements to: " + output);
	run("Set Measurements...", "integrated redirect=None decimal=9");
   	roiManager("Multi Measure");
   	saveAs("Results", output+"/Results_IntDen_"+title+".csv");
   	close("Results");
	print("Saving integrated density measurements to: " + output);

	//Tidy
	close("*");
	roiManager("delete");
}
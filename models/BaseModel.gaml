/**
* Name: BaseModel
* Based on the internal empty template. 
* Author: heiko
* Tags: 
*/


model BaseModel

/* Insert your model definition here */

global {
	int nb_collector <- 5;
	int nb_drifwood <- 50;
	int nb_pile <- 5;
	
	geometry shape <- rectangle(500, 100);
	
	init {
		create pile number: nb_pile {
			location <- point(rnd(500), rnd(0, 20));
		}
		create collector number: nb_collector {
			location <- point(rnd(500), rnd(0, 20));
		}
		create driftwood number: nb_drifwood {
			location <- point(rnd(500), rnd(30, 100));
		}
	}
}

species pile {
	int nb_wood <- 0;
	bool occupied <- false;
	
	aspect default {
		draw circle(4) color: (occupied = false) ? #white : #red;
	}
}

species collector skills: [moving]{
	int capacity <- rnd(5);
	bool go_collect <- false;
	geometry zone;
	rgb color <- #blue;
	pile pile_collector;
	int wood_collected <- 0;
	
	aspect default {
		draw triangle(5) color: color;
	}
}

species driftwood {
	rgb color <- #brown;
	aspect default {
		draw rectangle(5, 1) color: color;
	}
}

experiment base_model {
	output {
		display environment {
			species pile;
			species collector;
			species driftwood;
		}
	}
}
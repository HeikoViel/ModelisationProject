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
	int nb_pile <- nb_collector;
	int number_of_zone <- 4;
	int width <- 500;
	int height <- 100;
	
	geometry shape <- rectangle(width, height);
	point test <- point(0, 0);
	list<float> angle_location_zone <- [0.0, width / number_of_zone];
	
	init {
		
		create pile number: nb_pile {
			location <- point(rnd(width), rnd(80, 100));
		}
		create collector number: nb_collector {
			location <- point(rnd(width), rnd(80, 100));
		}
		create driftwood number: nb_drifwood {
			location <- point(rnd(width), rnd(0, 70));
		}
		
		loop times: number_of_zone {
			collector random_collector <- one_of(collector where(each.zone = nil));
			ask random_collector {
				zone <- rectangle({angle_location_zone[0], 0.0}, {angle_location_zone[1], 70.0});
			}
			angle_location_zone[0] <- angle_location_zone[0] + width / number_of_zone;
			angle_location_zone[1] <- angle_location_zone[1] + width / number_of_zone;
		}
	}
}

species pile {
	int nb_wood <- 0;
	bool is_occupied <- false;
	
	aspect default {
		draw circle(4) color: (is_occupied = false) ? #white : #red;
	}
}

species collector skills: [moving]{
	int capacity <- rnd(2,5);
	bool go_collect <- false;
	geometry zone <- nil;
	rgb color <- #blue;
	pile pile_collector;
	int wood_collected <- 0;
	driftwood driftwood_target;
	float speed <- 1.0;
	bool no_more_wood_on_zone;
	
	aspect default {
		draw triangle(5) color: color;
	}
	
	reflex choose_driftwood_target when: driftwood_target = nil and wood_collected < capacity and !no_more_wood_on_zone {
		if zone != nil {
			driftwood_target <- one_of(driftwood overlapping zone where(each.is_targeted = false));
			if driftwood_target != nil {
				ask driftwood_target {
					is_targeted <- true;
				}	
			}
			if driftwood_target = nil {
				no_more_wood_on_zone <- true;
			}
		}
	}
	
	reflex move when: driftwood_target != nil {
		do goto target: driftwood_target speed:speed ;
		if (location = driftwood_target.location) {
			ask driftwood_target {
				is_collected <- true;
			}
			driftwood_target <- nil;
			wood_collected <- wood_collected + 1;
		}
	}
	
	reflex go_to_pile when: wood_collected = capacity or no_more_wood_on_zone {
		if(pile_collector = nil) {
			pile_collector <- one_of(pile where(each.is_occupied = false));
			pile_collector.is_occupied <- true;
		}
		do goto target: pile_collector.location speed: speed;
		if (location = pile_collector.location) {
			ask pile_collector {
				nb_wood <- nb_wood + myself.wood_collected;
			}
			wood_collected <- 0;
		}	
	}
}

species driftwood {
	bool is_targeted <- false;
	bool is_collected <- false;
	aspect default {
		draw rectangle(5, 1) color: (is_collected = true) ? #white : #brown;
	}
}

experiment base_model {
	
	parameter "Nb_collector" var: nb_collector min: 0;
	parameter "Shore distance" var: width min: 300;
	parameter "Nb zone" var: number_of_zone min: 1 max: nb_collector;
	parameter "Nb driftwood" var: nb_drifwood min: 20;
	
	output {
		display environment {
			species pile;
			species driftwood;
			species collector;
			
		}
	}
}
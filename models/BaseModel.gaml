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
	int number_of_zone <- nb_collector;
	int width <- 500;
	int height <- 100;
	int capacity_max <- 5;
	
	geometry shape <- rectangle(width, height);
	point test <- point(0, 0);
	list<float> angle_location_zone <- [0.0, width / number_of_zone];
	
	int id <- 0;
	
	init {
		create collector number: nb_collector {
			location <- point(rnd(width), rnd(80, 100));
		}
		create driftwood number: nb_drifwood {
			location <- point(rnd(width), rnd(0, 70));
		}
		
		loop times: nb_collector{
			collector random_collector <- one_of(collector where(each.id_collector = -1));
			ask random_collector {
				id_collector <- id;
			}
			id <- id + 1;
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
	
	reflex pause when: !empty(collector where(each.pile_collector != nil)){
		if length(collector where(each.no_more_wood_on_zone = true)) = nb_collector and
				length(collector where(each.location = each.pile_collector.location)) = nb_collector{
					loop co over: collector {
 						write(co.name + " id : " + co.id_collector + ", wood collection : " + string(co.pile_collector.nb_wood));
 					}
					do pause;
		}
	}
}

species pile {
	int nb_wood <- 0;
	rgb color;
	int id_collector;
	
	aspect default {
		draw circle(4) color: color;
		draw "" + id_collector color: #black;
	}
}

species collector skills: [moving]{
	int capacity <- rnd(2,capacity_max);
	geometry zone <- nil;
	rgb color <- rnd_color(255);
	pile pile_collector;
	int wood_collected <- 0;
	driftwood driftwood_target;
	float speed <- 1.0;
	bool no_more_wood_on_zone;
	int id_collector <- -1;
	
	aspect default {
		draw zone color:#white border: color;
		draw triangle(5) color: color border: #black;
		draw "" + id_collector color: #black;
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
				do die;
			}
			driftwood_target <- nil;
			wood_collected <- wood_collected + 1;
		}
	}
	
	reflex go_to_pile when: wood_collected = capacity or no_more_wood_on_zone {
		if(pile_collector = nil) {
			create pile number: 1 {
				location <- point(rnd(width), rnd(80, 100));
				color <- myself.color;
				id_collector <- myself.id_collector;
				myself.pile_collector <- self;
			}
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
	
	parameter "Nb_collector" var: nb_collector min: 1;
	parameter "Shore distance" var: width min: 300;
	parameter "Nb driftwood" var: nb_drifwood min: 20;
	parameter "Capacity Max" var: capacity_max min: 2 max: 10;
	
	output {
		display environment {
			species pile;
			species collector;
			species driftwood;
		}
	}
}
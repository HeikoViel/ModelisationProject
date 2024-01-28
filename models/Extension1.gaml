/**
* Name: Extension1
* Based on the internal empty template. 
* Author: heiko
* Tags: 
*/


model Extension1

/* Insert your model definition here */

global {
	int nb_collector <- 5;
	int nb_thief <- 20;
	int nb_drifwood <- 500;
	int nb_pile <- nb_collector + nb_thief;
	int number_of_zone <- 5;
	int width <- 500;
	int height <- 100;
	
	geometry shape <- rectangle(width, height);
	point test <- point(0, 0);
	list<float> angle_location_zone <- [0.0, width / number_of_zone];
	
	int id <- 0;
	
	init {
		
		create pile number: nb_pile {
			location <- point(rnd(width), rnd(80, 100));
		}
		create collector number: nb_collector {
			location <- point(rnd(width), rnd(80, 100));
		}
		create thief number: nb_thief {
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
		
		loop times: nb_thief{
			thief random_thief <- one_of(thief where(each.id_collector = -1));
			ask random_thief {
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
	
	reflex pause when: !empty(collector where(each.pile_collector != nil)) and !empty(thief where(each.pile_collector != nil)){
		if length(collector where(each.no_more_wood_on_zone = true)) = nb_collector and
				length(collector where(each.location = each.pile_collector.location)) = nb_collector and
				length(thief where(each.location = each.pile_collector.location)) = nb_thief {
					loop co over: collector {
 						write(co.name + " id : " + co.id_collector + ", wood collection : " + string(co.pile_collector.nb_wood));
 					}
 					loop th over: thief {
 						write(th.name + " id : " + th.id_collector + ", wood collection : " + string(th.pile_collector.nb_wood));
 					}
					do pause;
		}
	}
}

species pile {
	int nb_wood <- 0;
	rgb color;
	bool is_occupied <- false;
	int id_collector;
	
	aspect default {
		draw circle(4) color: (is_occupied = false) ? #white : color;
		draw "" + id_collector color: (is_occupied = false) ? #white : #black;
	}
}

species person {
	int capacity <- rnd(2,5);
	rgb color <- rnd_color(255);
	pile pile_collector;
	int wood_collected <- 0;
	float speed <- rnd(0.5, 1.0);
	int id_collector <- -1;
}

species collector skills: [moving] parent: person{
	bool go_collect <- false;
	geometry zone <- nil;
	driftwood driftwood_target;
	bool no_more_wood_on_zone;
	
	aspect default {
		draw zone color:#white border: color;
		draw triangle(5) color: color border: #black;
		draw "" + id_collector color: #black;
	}
	
	reflex choose_driftwood_target when: driftwood_target = nil and wood_collected < capacity and !no_more_wood_on_zone
			and zone != nil {
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
	
	reflex move when: driftwood_target != nil {
		go_collect <- true;
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
		go_collect <- false;
		if(pile_collector = nil) {
			pile_collector <- one_of(pile where(each.is_occupied = false));
			pile_collector.color <- color;
			pile_collector.is_occupied <- true;
			pile_collector.id_collector <- id_collector;
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

species thief skills: [moving] parent: person {
	collector target_collector;
	bool free <- true;
	point test <- point(rnd(width), rnd(80, 100));
	
	aspect default {
		draw square(5) color: color border: #black;
		draw "" + id_collector color: #black;
	}
	
	reflex choose_target when: target_collector = nil and wood_collected < capacity and pile_collector = nil {
		collector random_collector <- one_of(collector where((each.go_collect) and (each.pile_collector != nil)));
		if random_collector != nil {
			if random_collector.pile_collector.nb_wood > 0 {
				target_collector <- random_collector;
				free <- false;
			}
		}
	}
	
	//Add reflex to move the thief
	reflex move when: target_collector != nil {
		pile pile_targeted <- target_collector.pile_collector;
		do goto target: pile_targeted speed:speed ;
		if (location = pile_targeted.location) {
			if pile_targeted.nb_wood > capacity - wood_collected {
				pile_targeted.nb_wood <- pile_targeted.nb_wood - (capacity - wood_collected);
				wood_collected <- capacity;
			} else {
				wood_collected <- wood_collected + pile_targeted.nb_wood;
				pile_targeted.nb_wood <- 0;
			}
			target_collector <- nil;
			free <- true;
		}
	}
		
	reflex check_target when: target_collector != nil {
		if !target_collector.go_collect {
			target_collector <- nil;
			free <- true;
		}
	}
	
	reflex go_to_random when: free = true {
		do goto target: test speed:speed;
	}
	
	reflex go_to_pile when: wood_collected = capacity {
		do go_to_pile_action;
	}
	
	action go_to_pile_action {
		free <- false;
		if(pile_collector = nil) {
			pile_collector <- one_of(pile where(each.is_occupied = false));
			pile_collector.color <- color;
			pile_collector.is_occupied <- true;
			pile_collector.id_collector <- id_collector;
		}
		do goto target: pile_collector.location speed: speed;
		if (location = pile_collector.location) {
			ask pile_collector {
				nb_wood <- nb_wood + myself.wood_collected;
			}
			wood_collected <- 0;
		}	
	}
	
	reflex finish_go_to_pile {
		if !empty(collector where(each.pile_collector != nil)) {
			if length(collector where(each.no_more_wood_on_zone = true)) = nb_collector and
				length(collector where(each.location = each.pile_collector.location)) = nb_collector {
					do go_to_pile_action;
			}
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

experiment extension_1 {
	
	parameter "Nb_collector" var: nb_collector min: 0;
	parameter "Shore distance" var: width min: 300;
	parameter "Nb zone" var: number_of_zone min: 1 max: nb_collector;
	parameter "Nb driftwood" var: nb_drifwood min: 20;
	
	output {
		display environment {
			species pile;
			species collector;
			species thief;
			species driftwood;
		}
	}
}
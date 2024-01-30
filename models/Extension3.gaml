/**
* Name: Extension3
* Based on the internal empty template. 
* Author: heiko
* Tags: 
*/


model Extension3


global {
	int nb_collector <- 7;
	int nb_drifwood <- 50;
	int number_of_zone <- 5;
	int width <- 500;
	int height <- 100;
	int capacity_max <- 5;
	
	geometry shape <- rectangle(width, height);
	list<float> angle_location_zone <- [0.0, width / number_of_zone];
	
	int id <- 0;
	
	init {
		create collector number: nb_collector {
			location <- point(rnd(width), rnd(80, 100));
		}
		create driftwood number: nb_drifwood {
			location <- point(rnd(width), rnd(0, 70));
		}
		create authorities number: 5 {
			location <- point(rnd(width), rnd(80, 100));
			rnd_location <- location;
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
		if length(collector where(each.no_more_wood_on_zone = true)) = number_of_zone and
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
	bool is_occupied <- false;
	int id_collector;
	bool is_monitored <- false;
	
	aspect default {
		draw circle(4) color: color;
		draw "" + id_collector color: #black;
	}
	
	reflex put_monitor {
		if empty(authorities where(each.location distance_to self.location < 30)) {
			is_monitored <- false;
		} else {
			is_monitored <- true;
		}
		
	}
}

species collector skills: [moving]{
	int capacity <- rnd(2,capacity_max);
	geometry zone <- nil;
	rgb color <- rnd_color(255);
	pile pile_collector;
	int wood_collected <- 0;
	float speed <- 1.0;
	int id_collector <- -1;
	
	driftwood driftwood_target;
	bool no_more_wood_on_zone;
	bool gather <- false;
	
	
	bool steal <- false;
	collector target_collector;
	pile pile_targeted;
	bool free <- false;
	point leave_target_pile <- point(rnd(width), rnd(80, 100));
	
	
	aspect default {
		draw zone color:#white border: color;
		draw triangle(5) color: color border: #black;
		draw "" + name color: #black;
	}
	
	reflex choose_driftwood_target when: driftwood_target = nil and wood_collected < capacity and !no_more_wood_on_zone and gather{
		if zone != nil {
			free <- false;
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
	
	action go_to_pile_action {
		if(pile_collector = nil) {
			create pile number: 1 {
				location <- point(rnd(width), rnd(80, 100));
				color <- myself.color;
				is_occupied <- true;
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
			gather <- false;
			steal <- false;
		}	
	}
	
	reflex go_to_pile when: wood_collected = capacity or no_more_wood_on_zone {
		free <- false;
		do go_to_pile_action;
	}
	
	reflex choose_target when: target_collector = nil and steal {
		collector random_collector <- one_of(collector where((each.pile_collector != nil) and
			(each.location distance_to each.pile_collector.location > 50)
		));
		if random_collector != nil {
			if random_collector.pile_collector.nb_wood > 0 {
				target_collector <- random_collector;
				free <- false;
			}
		}
	}
	
	reflex go_to_random when: free = true {
		do goto target: test speed:speed;
	}
	
	reflex move when: target_collector != nil or driftwood_target != nil {
		if steal {
			pile_targeted <- target_collector.pile_collector;
			do goto target: pile_targeted speed:speed ;
			if (location = pile_targeted.location) {
				if pile_targeted.nb_wood > capacity - wood_collected {
					pile_targeted.nb_wood <- pile_targeted.nb_wood - (capacity - wood_collected);
					wood_collected <- capacity;
				} else {
					wood_collected <- wood_collected + pile_targeted.nb_wood;
					pile_targeted.nb_wood <- 0;
					ask collector where(each.target_collector = target_collector) {
						if self.target_collector.pile_collector = myself.pile_targeted and self != myself{
							self.target_collector <- nil;
							steal <- false;
						}
					}
					ask collector where(each.id_collector = target_collector.id_collector) {
						pile_collector <- nil;
					}
					ask pile where(each.id_collector = pile_targeted.id_collector) {
						do die;
					}
				}
				target_collector <- nil;
				steal <- false;
				free <- true;
			}
		} else {
			do goto target: driftwood_target speed:speed ;
			if (location = driftwood_target.location) {
				ask driftwood_target {
					do die;
				}
				driftwood_target <- nil;
				wood_collected <- wood_collected + 1;
				gather <- false;
			}
		}
	}
	
	reflex check_target when: target_collector != nil {
		if (target_collector.location distance_to target_collector.pile_collector.location < 50) and target_collector.pile_collector.is_monitored {
			target_collector <- nil;
			steal <- false;
		}
	}
	
	reflex go_to_random when: free = true {
		do goto target: leave_target_pile speed:speed;
	}
	
	reflex steal when: pile_collector = nil and !gather and !steal and wood_collected < capacity {
		if zone != nil {
			bool choose <- flip(0.7);
			if choose or (collector count (each.steal) = nb_collector - 1) {
				gather <- true;
			} else {
				steal <- true;
			}
		} else {
			steal <- true;
		}
	}
	
	reflex gather when: pile_collector != nil and !gather and wood_collected < capacity{
		if zone != nil and !no_more_wood_on_zone{
			gather <- true;
		}
	}
}

species authorities skills: [moving] {
	float speed <- 1.0;
	point rnd_location;
	
	aspect default {
		draw circle(2) color: #red;
	}
	
	reflex chose_other_location when: rnd_location = self.location {
		rnd_location <- point(rnd(width), rnd(80, 100));
	}
	
	reflex go_to_location when: rnd_location != self.location {
		do goto target: rnd_location speed:speed;
	}
	
}

species driftwood {
	bool is_targeted <- false;
	bool is_collected <- false;
	aspect default {
		draw rectangle(5, 1) color: (is_collected = true) ? #white : #brown;
	}
}

experiment extension3 {
	
	float minimum_cycle_duration <- 0.05;
	
	parameter "Nb_collector" var: nb_collector min: 1;
	parameter "Shore distance" var: width min: 300;
	parameter "Nb driftwood" var: nb_drifwood min: 20;
	parameter "Capacity Max" var: capacity_max min: 2 max: 10;
	
	output {
		display environment {
			species pile;
			species authorities;
			species collector;
			species driftwood;
		}
	}
}


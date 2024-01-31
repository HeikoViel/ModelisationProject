/**
* Name: Extension3
* Based on the internal empty template. 
* Author: heiko
* Tags: 
*/


model Extension3


global {
	int nb_collector <- 20;
	int nb_drifwood <- 100;
	int number_of_zone <- 12;
	int width <- 1000;
	int height <- 100;
	int capacity_max <- 10;
	int nb_authorities <- 3;
	int size_group <- 8;
	int number_of_group;
	
	int distance_monitor <- 50;
	
	geometry shape <- rectangle(width, height);
	list<float> angle_location_zone <- [0.0, width / number_of_zone];
	
	int id <- 0;
	
	init {
		if nb_collector mod size_group = 0 {
			number_of_group <- nb_collector div size_group;
		} else {
			number_of_group <- (nb_collector div size_group) + 1;
		}
		create collector number: nb_collector {
			location <- point(rnd(width), rnd(80, 100));
		}
		create driftwood number: nb_drifwood {
			location <- point(rnd(width), rnd(0, 70));
		}
		create authorities number: nb_authorities {
			location <- point(rnd(width), rnd(80, 100));
			rnd_location <- location;
		}
		
		int id_Groups <- 0;
		
		loop times: number_of_group {
			int i <- 0;
			loop while: i < size_group {
				collector co <- one_of(collector where(each.id_Group = -1));
				co.id_Group <- id_Groups;
				if(collector count(each.id_Group != -1) = 0) {
					break;
				}
				i <- i + 1;
			}
			id_Groups <- id_Groups + 1;
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
				length(collector where(each.pile_collector != nil) where(each.location = each.pile_collector.location)) = nb_collector{
					loop co over: collector {
						bool has_zone <- false;
						if co.zone != nil {
							has_zone <- true;
						}
 						write(co.name + " id : " + co.id_collector + ", has zone : " + has_zone +
 							", wood collection : " + string(co.pile_collector.nb_wood) + 
 							"; wood stolen : " + string(co.wood_stolen)
 						);
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
		collector owner <- one_of(collector where(each.id_collector = self.id_collector));
		if empty(authorities where(each.location distance_to self.location < distance_monitor)) and 
			empty(collector where(each.id_Group = owner.id_Group) where (each.location distance_to self.location < distance_monitor)) {
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
	int previous_wood_collected;
	int wood_stolen <- 0;
	int reinit_collector <- 0;
	
	int id_Group <- -1;
	
	
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
			(each.location distance_to each.pile_collector.location > distance_monitor) and (each.id_Group != self.id_Group)
		));
		if random_collector != nil {
			if random_collector.pile_collector.nb_wood > 0 and !random_collector.pile_collector.is_monitored{
				target_collector <- random_collector;
				free <- false;
				reinit_collector <- 0;
			}
		} else {
			reinit_collector <- reinit_collector + 1;
			if reinit_collector = 200 {
				steal <- false;
				reinit_collector <- 0;
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
				previous_wood_collected <- wood_collected;
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
				wood_stolen <- wood_stolen + (wood_collected - previous_wood_collected);
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
		if (target_collector.location distance_to target_collector.pile_collector.location < distance_monitor) or target_collector.pile_collector.is_monitored {
			target_collector <- nil;
			steal <- false;
		}
	}
	
	reflex go_to_random when: free = true {
		do goto target: leave_target_pile speed:speed;
	}
	
	reflex steal when: pile_collector = nil and !gather and !steal and wood_collected < capacity {
		if zone != nil {
			bool choose <- flip(0.5);
			if choose or ((collector where (each.zone != nil)) count (each.steal) = number_of_zone - (collector count (each.no_more_wood_on_zone)) - 1) {
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
	
	reflex finish_go_to_pile {
		if length(collector where(each.no_more_wood_on_zone = true)) = number_of_zone {
			free <- false;
			do go_to_pile_action;
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

experiment extension2 {
	
	float minimum_cycle_duration <- 0.05;
	
	parameter "Nb_collector" var: nb_collector min: 1;
	parameter "Shore distance" var: width min: 300;
	parameter "Nb driftwood" var: nb_drifwood min: 20;
	parameter "Capacity Max" var: capacity_max min: 2 max: 10;
	parameter "Nb Authorities" var: nb_authorities min: 0 max: 5;
	parameter "Distance Monitor" var: distance_monitor min: 20 max: 50;
	parameter "Size Group" var: size_group min: 1;
	
	output {
		display environment {
			species pile;
			species authorities;
			species collector;
			species driftwood;
		}
	}
}


/**
* Name: newGestion
* Based on the internal empty template. 
* Author: ermad
* Tags: 
*/


//model newGestion

/* Insert your model definition here */

model KnotweedViability

global {
	// ========================================================
    // TEMPS
    // ========================================================

    float dt <- 1.0 / 12.0;
    int T;
     int natural_duration_limit_months <- 420;

    int management_duration_months <- 120;
    
    int natural_result_T <- 0;

    float natural_result_tau <- 0.0;


    // ========================================================
    // GRILLE
    // ========================================================

    int grid_width <- 100;
    int grid_height <- 100;


    // ========================================================
    // PHASE DE CONSTRUCTION NATURELLE
    // ========================================================

    int initial_population <- 1;

    int target_population <- 1000;

    // Aucune gestion pendant la phase naturelle
    float tau_natural <- 0.0;
    
    // Phase de  gestion 
    float tau_management <- 3.0;


    // ========================================================
    // CROISSANCE
    // ========================================================

    float K_biomass <- 12.7;

    float L_growth <- 0.26;

    float initial_biomass <- 1.73;


    // ========================================================
    // REPRODUCTION
    // ========================================================

    float birth_rate_max <- 0.18;

    float distance_parent <- 0.2;

    float distance_competition <- 0.15;


    // ========================================================
    // DISPERSION
    // ========================================================

    float gamma_shape <- 4.34;

    float gamma_scale <- 2.36;


    // ========================================================
    // MORTALITE
    // ========================================================

    float death_scale <- 1.12;

    float death_decay <- 2.32;


    // ========================================================
    // RHIZOMES
    // ========================================================

    float rhizome_extension_rate <- 0.174;

    float rhizome_max_radius <- 7.0;

    float crown_formation_probability <- 0.0145;


    // ========================================================
    // GESTION
    // ========================================================

    float tau <- 0.0;

    float mowing_fraction <- 0.90;

    float mowing_parameter <- 0.11;
    bool is_manage <- false;


    // ========================================================
    // ETAT X(t) = (A(t),N(t))
    // ========================================================

    float current_area <- 0.0;

    int current_population <- 0;


    // ========================================================
    // ETAT DE REFERENCE X0 = (A0,N0)
    // ========================================================

    float A0 <- 0.0;

    int N0 <- 0;


    // ========================================================
    // VIABILITE
    // ========================================================

    float area_viability_limit <- 0.0;

    float population_viability_limit <- 0.0;


    bool in_K <- false;

    bool ever_reached_K <- false;

    bool remained_in_K <- true;


    int time_to_K_month <- -1;

    float time_to_K_year <- -1.0;


    // ========================================================
    // SIMULATION
    // ========================================================

    int month <- T*12;

    int construction_months <- 0;

    bool natural_phase_finished <- false;

    bool control_phase_started <- false;

    bool simulation_finished <- false;


    // ========================================================
    // IDENTIFICATION DE LA REPETITION
    // ========================================================

    int replication <- 1;
    bool is_batch <- false;
    
    
     // ========================================================
    // CALCUL DE N(t)
    // ========================================================

    int population_size {

        return length(Couronne);
    }
    
    
    float invaded_area {

        list<point> crown_points <- Couronne collect each.location;

        if length(crown_points) < 3 {

            return 0.0;

        }

        geometry crown_geometry <- geometry(crown_points);

        geometry hull <- convex_hull(crown_geometry);

        return hull.area;
    }
    
    
    
    // ========================================================
    // MISE A JOUR DE X(t)
    //
    // X(t) = (A(t),N(t))
    // ========================================================

    action update_state {

        current_population <- population_size;

        current_area <- invaded_area;
    }


    // ========================================================
    // TEST D'APPARTENANCE A K
    //
    // K = {(A,N) :
    //      A <= 0.05 A0
    //      N <= 0.05 N0}
    // ========================================================

    action update_viability {

        // Si la phase de contrôle n'a pas encore
        // défini A0 et N0, on ne peut pas tester K.

        if (control_phase_started) {

            in_K <-
                current_area <= area_viability_limit
                and
                current_population
                    <= population_viability_limit;


            // ----------------------------------------------
            // Première entrée dans K
            // ----------------------------------------------

            if (in_K and !ever_reached_K) {

                ever_reached_K <- true;

                time_to_K_month <- month;

                time_to_K_year <-
                    month * dt;
            }


            // ----------------------------------------------
            // Si le système quitte K après l'avoir atteint
            // ----------------------------------------------

            if (ever_reached_K and !in_K) {

                remained_in_K <- false;
            }
        }
    }
    
    
    // ========================================================
    // DEFINITION DE L'ETAT DE REFERENCE
    // ========================================================
    
     action define_reference_state {

    // Calcul direct de la référence
    N0 <- length(Couronne);

    if (N0 >= 3) {
        list<point> pts <- Couronne collect each.location;
        geometry geom <- geometry(pts);
        geometry hull <- convex_hull(geom);
        A0 <- hull.area;
    } else {
        A0 <- 0.0;
    }

    write "========================================";
    write "REFERENCE DEFINIE";
    write "Mois = " + month;
    write "Temps = " + (month * dt) + " ans";
    write "N0 = " + N0;
    write "A0 = " + A0;
    write "========================================";
}
    
    
    action debug_state(string label) {

    int n <- length(Couronne);

    float a <- 0.0;

    if (n >= 3) {
        list<point> pts <- Couronne collect each.location;
        geometry geom <- geometry(pts);
        geometry hull <- convex_hull(geom);
        a <- hull.area;
    }

    write "========================================";
    write label;
    write "Mois = " + month;
    write "Couronnes = " + n;
    write "Surface calculee = " + a;
    write "========================================";
}
    
    
     // ========================================================
    // PHASE NATURELLE
    // ========================================================
    
    reflex natural_invasion
    when: !natural_phase_finished {

    // ----------------------------------------------------
    // Pas de gestion
    // ----------------------------------------------------

    tau <- tau_natural;
    
    

    // ----------------------------------------------------
    // Dynamique biologique
    // ----------------------------------------------------

    ask Couronne {

        do grow;
        do reproduce;
        do mortality;
    }
    
	do define_reference_state;

    // ----------------------------------------------------
    // Mise à jour de l'état
    // ----------------------------------------------------

    do update_state;

    construction_months <- construction_months + 1;
    month <- month + 1;

    // ----------------------------------------------------
    // Enregistrement de la phase naturelle
    // ----------------------------------------------------

    //do record_natural_state;

    // ----------------------------------------------------
    // Condition d'arrêt
    // ----------------------------------------------------

    if (current_population >= target_population) {

        natural_phase_finished <- true;

        do define_reference_state;

        control_phase_started <- true;

        // Enregistrer l'état de référence
        current_population <- N0;
		current_area <- A0;
		
        //do record_state("reference");
        
      }
   }
   
   
   
    // ========================================================
    // PHASE DE CONTROLE
    // ========================================================
    
    reflex management_phase
    when:
        N0 >= target_population {
        	
         // ----------------------------------------------------
         // Gestion active
         // ----------------------------------------------------
         
         //do define_reference_state;
         //do update_state;

        tau <- tau_management;
        
        
        write "****************************************";
		write "ENTREE DANS LA PHASE DE GESTION";
		write "Mois = " + month;
		write "Temps = " + (month * dt) + " ans";
		write "tau = " + tau;
		write "Couronnes = " + length(Couronne);
		write "Surface = " + A0;
		write "****************************************";
        	
        	
         // ----------------------------------------------------
        // DYNAMIQUE BIOLOGIQUE
        // ----------------------------------------------------

        ask Couronne {

            do grow;

            do reproduce;

            do mortality;
        }
        
        
         // ----------------------------------------------------
        // ACTION DU GESTIONNAIRE
        // ----------------------------------------------------

        ask Gestionnaire {

            do manage;
        }


        // ----------------------------------------------------
        // MISE A JOUR DE X(t)
        // ----------------------------------------------------

        do update_state;


        // ----------------------------------------------------
        // TEST DE VIABILITE
        // ----------------------------------------------------

        do update_viability;


        // ----------------------------------------------------
        // ENREGISTREMENT CSV
        // ----------------------------------------------------

        //do record_state("control");


        // ----------------------------------------------------
        // INCREMENT DU TEMPS
        // ----------------------------------------------------

        month <- month + 1;
    
        
        }
   
   
   
   
   
   // ========================================================
    // INITIALISATION DU MODELE
    // ========================================================
    
    init {
    	
    	// ----------------------------------------------------
        // Initialiser le CSV
        // ----------------------------------------------------
        
        //do initialize_csv;
        do update_state;
        //do record_natural_state;
            
            
         // ----------------------------------------------------
        // UNE SEULE COURONNE
        // ----------------------------------------------------
        
        create Couronne
        number: initial_population {
        	location <- {
                grid_width / 2.0,
                grid_height / 2.0
            };
            biomass <- initial_biomass;

            is_initial <- true;
        }
        
        
        // ----------------------------------------------------
        // Etat initial
        // ----------------------------------------------------

        //do update_state;

        //do record_state("initial");
        do update_state;

		write "===== ETAT INITIAL =====";
		write "Nombre de Couronne = " + length(Couronne);
		write "Population = " + current_population;
		write "Aire = " + current_area;
		write "========================";
		
		//do record_state("initial");


        write "============================================";

        write "DEMARRAGE";

        write "N(0) = "
              + current_population;

        write "A(0) = "
              + current_area;

        write "============================================";
    	
    }
    
    
    /*reflex save_result when: (N0 > 0) and (A0 > 0){
    	save [
			cycle,
	        T,
	        month * dt,
	        N0,
	        A0
    ]
    to: "../results/knotweed_natural_tau0.csv"
    type: "csv"
	 rewrite: (cycle = 0) ? true : false;
    	
    }*/
    
    reflex stop_simulation when: (N0 >= target_population) {
		do pause;
	}
    
    
}




//////////////////////////////////////////////////////////////////
//                    AGENT PARCELLE
//////////////////////////////////////////////////////////////////

// La parcelle est ici une grille.
// Chaque cellule représente une unité spatiale de l'environnement.

grid Parcelle
    width: grid_width
    height: grid_height
    neighbors: 8 {

    int number_crowns <- 0;

    bool occupied <- false;


    reflex update_cell {

        number_crowns <- length(Couronne inside self);

        occupied <- number_crowns > 0;

        if occupied {

            color <- #green;

        } else {

            color <- #white;

        }

    }

}




// ============================================================
// AGENT COURONNE
// ============================================================

species Couronne {

    float biomass <- initial_biomass;

    bool is_initial <- false;


    // ========================================================
    // CROISSANCE
    // ========================================================

    action grow {

        biomass <-
            biomass
            + dt
            * L_growth
            * (K_biomass - biomass);


        if (biomass > K_biomass) {

            biomass <- K_biomass;
        }
    }


    // ========================================================
    // MORTALITE
    // ========================================================

    action mortality {

        float mortality_rate;


        mortality_rate <-
            death_scale
            * exp(-death_decay * biomass);


        if (rnd(1.0)
            < mortality_rate * dt) {

            do die;
        }
    }


    // ========================================================
    // REPRODUCTION
    // ========================================================

    action reproduce {

        int local_count <-
            length(
                Couronne where (
                    each distance_to(self)
                    <= distance_parent
                )
            );


        if (local_count < 3) {

            float birth_probability <-
                1.0
                - exp(
                    -birth_rate_max * dt
                );


            if (rnd(1.0)
                < birth_probability) {


                // ------------------------------------------
                // Distance de dispersion
                // ------------------------------------------

                float dispersal_distance <-
                    gamma_rnd(
                        gamma_shape,
                        gamma_scale
                    );


                // ------------------------------------------
                // Angle aléatoire
                // ------------------------------------------

                float angle <-
                    rnd(360.0);


                // ------------------------------------------
                // Nouvelle position
                // ------------------------------------------

                point new_position <- {

                    location.x
                    + dispersal_distance
                    * cos(angle),

                    location.y
                    + dispersal_distance
                    * sin(angle)
                };


                // ------------------------------------------
                // Competition
                // ------------------------------------------

                bool position_free <-
                    empty(
                        Couronne where (
                            each distance_to(
                                new_position
                            )
                            <= distance_competition
                        )
                    );


                // ------------------------------------------
                // Limites de la grille
                // ------------------------------------------

                bool inside_grid <-

                    new_position.x >= 0
                    and
                    new_position.x <= grid_width

                    and

                    new_position.y >= 0
                    and
                    new_position.y <= grid_height;


                // ------------------------------------------
                // Création
                // ------------------------------------------

                if (
                    position_free
                    and
                    inside_grid
                ) {

                    create Couronne {

                        location <- new_position;

                        biomass <-
                            initial_biomass;

                        is_initial <- false;
                    }
                }
            }
        }
    }


    // ========================================================
    // FAUCHE
    // ========================================================

    action mow {

        biomass <-
            biomass
            * (
                1.0
                - exp(
                    -mowing_parameter
                    * biomass
                )
            );
    }
    
     // ============================================================
    // AFFICHAGE
    // ============================================================

    aspect base {

        draw circle(0.5)
            color: #darkgreen;

    }
}



// ============================================================
// AGENT PARCELLE
// ============================================================

/*species Parcelle {

    int cell_id <- 0;

    bool occupied <- false;
}*/



// ============================================================
// AGENT GESTIONNAIRE
// ============================================================

species Gestionnaire {


    action manage {

        // ----------------------------------------------------
        // Probabilité d'une intervention pendant dt
        // ----------------------------------------------------

        float mowing_probability <-
            1.0
            - exp(
                -tau * dt
            );


        if (rnd(1.0)
            < mowing_probability) {


            // ------------------------------------------------
            // Nombre de couronnes à faucher
            // ------------------------------------------------

            int number_to_mow <-
                int(
                    mowing_fraction
                    * length(Couronne)
                );


            if (number_to_mow > 0) {


                // --------------------------------------------
                // Sélection aléatoire
                // --------------------------------------------

                list<Couronne> selected_crowns <-
                    sample(
                        Couronne,
                        number_to_mow
                    );


                // --------------------------------------------
                // Fauchage
                // --------------------------------------------

                ask selected_crowns {

                   do mow;
                }
            }
        }
    }
}



// ============================================================
// EXPERIMENT
// ============================================================

experiment NaturalInvasion_gui type: gui {


    parameter
        "Durrée"
        var: T
        min: 0
        max: 15
        step: 1;


    output {


        // ====================================================
        // VISUALISATION
        // ====================================================

        display "Invasion" {

            grid Parcelle border: #gray;

            species Couronne aspect: base;
            
        }


        // ====================================================
        // VARIABLES D'ETAT
        // ====================================================

        monitor
            "N(t)"
            value: current_population;


        monitor
            "A(t)"
            value: current_area;


        // ====================================================
        // ETAT DE REFERENCE
        // ====================================================

        monitor
            "N0"
            value: N0;


        monitor
            "A0"
            value: A0;


        // ====================================================
        // CONTRAINTES
        // ====================================================

        monitor
            "Limite N"
            value: population_viability_limit;


        monitor
            "Limite A"
            value: area_viability_limit;


        // ====================================================
        // VIABILITE
        // ====================================================

        monitor
            "Dans K"
            value: in_K;


        monitor
            "K atteint"
            value: ever_reached_K;


        monitor
            "Reste dans K"
            value: remained_in_K;


        monitor
            "Temps entree K"
            value: time_to_K_year;


        // ====================================================
        // PHASE NATURELLE
        // ====================================================

        monitor
            "Population cible atteinte"
            value: natural_phase_finished;


        monitor
            "Mois construction"
            value: construction_months;
    }
    
    
}



experiment management_gui

    type: gui {


    parameter

        "Durée de gestion (années)"

        var: T

        min: 1

        max: 15

        step: 1;


    parameter

        "Intensité de gestion tau"

        var: tau

        min: 0.0

        max: 12.0

        step: 0.5;
        
     parameter "Management mode:" var: is_manage <- true;


    output {


        display "Invasion" {

            grid Parcelle border: #gray;

            species Couronne aspect: base;

        }


        monitor

            "Temps total (années)"

            value: month * dt;

        monitor

            "Temps gestion (années)"

            value: T * dt;

        monitor

            "Phase naturelle terminée"

            value: natural_phase_finished;

        monitor

            "Phase de gestion"

            value: control_phase_started;

        monitor

            "Simulation terminée"

            value: simulation_finished;

        monitor

            "N(t)"

            value: current_population;

        monitor

            "A(t)"

            value: current_area;

        monitor

            "N0"

            value: N0;

        monitor

            "A0"

            value: A0;

        monitor

            "Limite N"

            value: population_viability_limit;

        monitor

            "Limite A"

            value: area_viability_limit;

        monitor

            "Dans K"

            value: in_K;

        monitor

            "K atteint"

            value: ever_reached_K;

        monitor

            "Reste dans K"

            value: remained_in_K;

        monitor

            "Temps entrée K (années)"

            value: time_to_K_year;

    }

}

    
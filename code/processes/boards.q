\d .boards

/- enable / disable tickerplant replay
replay:@[value;`replay;1b];

/- tables to subscribe to
subscribeto:@[value;`subscribeto;`];

/- syms to subscribe to
subscribetosyms:@[value;`subscribetosyms;`];

upd:{[t;x] t insert x}

/- function for subscribing to the tickerplant
sub:{[]
  if[count s:.sub.getsubscriptionhandles[`tickerplant;();()!()];
    .lg.o[`subscribe;"Available tickerplant found, attempting to subscribe"];
    subinfo: .sub.subscribe[.boards.subscribeto;.boards.subscribetosyms;1b;.boards.replay;first s];
    @[`.boards;;:;]'[key subinfo;value subinfo]]
 }

\d .

/- calculating boards
coords:("SSS"; enlist ",") 0: first .proc.getconfigfile["allAirportCoords.csv"];
coords:`depAirport xcol coords;

/- Retrieves Airline Codes for translation later
codes:(!).("SS";":")0: first .proc.getconfigfile["allAirlineCodes.txt"];

/- Get airports codes as a dictionary
airports:("  SS"; enlist ",") 0: first .proc.getconfigfile["allAirportCodes.csv"];
airports:( airports`code)!(airports`Airport);

final:();
allSyms:key airports;

/- For direction takes `depAirport or `arivAirport
getRaw:{[direction;airport]
  tab:?[`flights;enlist (=;direction;enlist airport);0b;()];
  distinct select Airline:codes[sym], depAirport, depTime:"u"$depTime, arivTime:"u"$arivTime, arivAirport, FlightNumber from tab where arivTime > .z.z
 }

/- select a particular flight, used for departure board entries
nflight:{[direction;airport;n] (getRaw[direction;airport])[n]}

/- Renames the columns as necessary so they're all unique and can be lj'ed onto final
/- requests the nth departure / arrival as necessary from all syms
nallDep:{[n]
  u:string n; 
  tab:select Airline, depTime, arivTime, arivAirport, FlightNumber by depAirport from nflight[`depAirport;;n]'[allSyms]; 
  (`depAirport,`$u,/:("Airline";"depTime";"arivTime";"arivAirport";"FlightNumber")) xcol tab
 }

/- The "Departing airport" and "Arriving Airport" are swapped here so the LJ will work and data will be placed properly on the map
/- The q on the end of the names is to distinguish them from the departures when doing the html tables in kx dashboards. 
nallAriv:{[n]
  u:string n;
  tab:select  Airline, depTime, arivTime, depAirport, FlightNumber by arivAirport from nflight[`arivAirport;;n]'[allSyms];
  (`depAirport,`$u,/:("Airlineq";"depTimeq";"arivTimeq";"arivAirportq";"FlightNumberq")) xcol tab 
 }

resetFinal:{`final set coords}

/- adds a set of columns representing the nth arrival / departure to the 
addFlight:{`final set (lj/)(value`final;nallDep x;nallAriv x)}

/- adds color coding to airports depending on how busy they are
calcColors:{
  symsInUse:exec sym from final;
  counts:count getRaw'[`depAirport`arivAirport]'[symsInUse];
  c:`s#0 6 16!`$("#39a105";"#d48c19";"#ff0000"); 
  `final set update color:c[counts] from final;
 }

/- actually calculates departures and arrival boards
calcBoards:{
  resetFinal[];
  addFlight'[til 5];
  `final set update sym:depAirport, depAirport:airports[depAirport] from 0!final;
  calcColors[];
 }

/- Tickerplant stuff
.servers.startup[]
.servers.CONNECTIONS:`tickerplant;

/- assigning update and eod functions
upd:.boards.upd;

/- connecting to tickerplant
.servers.CONNECTIONS:`tickerplant;
.servers.startupdepcycles[`tickerplant;10;0W]

/- subscribe to the quotes table
.boards.sub[];
.timer.repeat[.proc.cp[];0Wp;0D00:01:00.000;(`calcBoards;`);"Calculate Boards"];

SET FOREIGN_KEY_CHECKS = 0;
DROP TABLE IF EXISTS airport;
DROP TABLE IF EXISTS route;
DROP TABLE IF EXISTS weekly_schedule;
DROP TABLE IF EXISTS day;
DROP TABLE IF EXISTS year;
DROP TABLE IF EXISTS flight;
DROP TABLE IF EXISTS reservation;
DROP TABLE IF EXISTS tickets;
DROP TABLE IF EXISTS passenger;
DROP TABLE IF EXISTS contact;
DROP TABLE IF EXISTS booking;
DROP TABLE IF EXISTS payment;
DROP PROCEDURE IF EXISTS addYear;
DROP PROCEDURE IF EXISTS addDay;
DROP PROCEDURE IF EXISTS addDestination;
DROP PROCEDURE IF EXISTS addRoute;
DROP PROCEDURE IF EXISTS addFlight;
DROP PROCEDURE IF EXISTS addReservation;
DROP PROCEDURE IF EXISTS addPassenger;
DROP PROCEDURE IF EXISTS addContact;
DROP PROCEDURE IF EXISTS addPayment;
DROP FUNCTION IF EXISTS calculatePrice;
DROP FUNCTION IF EXISTS calculateFreeSeats;
DROP TRIGGER IF EXISTS issueTicket;
DROP VIEW IF EXISTS allFlights;
SET FOREIGN_KEY_CHECKS = 1;

create table airport(
code varchar(3) not null,
name varchar(30),
country varchar(30),
constraint pk_airport primary key(code));

delimiter //
create procedure addDestination(in code varchar(3), in name varchar(30), in country varchar(30))
begin
insert into airport(code,name,country) values(code,name,country);
end;//
delimiter ;

create table year(
num integer,
profit_factor double(4,2),
constraint pk_year primary key(num));

delimiter //
create procedure addYear(in year integer, in factor double(4,2))
begin
insert into year(num,profit_factor) values(year,factor);
end;//
delimiter ;

create table day(
name varchar(10),
factor double(4,2),
year integer,
constraint foreign key(year) references year(num),
constraint pk_day primary key(name));

delimiter //
create procedure addDay(in year integer, in day varchar(10), in factor double(4,2))
begin
insert into day(name,factor,year) values(day,factor,year);
end;//
delimiter ;

create table route(
id integer not null auto_increment,
price double(8,3),
year integer,
arr_airport varchar(3),
dep_airport varchar(3),
constraint foreign key(arr_airport) references airport(code),
constraint foreign key(dep_airport) references airport(code),
constraint pk_route primary key(id));

delimiter //
create procedure addRoute(in dep_code varchar(3), in arr_code varchar(3), in year integer, in route_price double(8,3))
begin
insert into route(dep_airport,arr_airport,year,price) values(dep_code,arr_code,year,route_price);
end;//
delimiter ;

create table weekly_schedule(
id integer not null auto_increment,
route integer,
dep_time time,
day varchar(10),
year integer,
constraint foreign key(route) references route(id),
constraint foreign key(day) references day(name),
constraint foreign key(year) references year(num),
constraint pk_schedule primary key(id));

create table flight(
id integer not null auto_increment,
week integer,
schedule integer,
constraint foreign key(schedule) references weekly_schedule(id),
constraint pk_flight primary key(id));

delimiter //
create procedure addFlight(in dep_code varchar(3), in arr_code varchar(3), in year integer, in day varchar(10), in dep_time time)
begin
declare counter int unsigned default 1; /*has to be right after the BEGIN statement*/
insert into weekly_schedule(dep_time,day,year,route)
  select dep_time,day,year,r.id
  from route r
  where r.arr_airport=arr_code and r.dep_airport=dep_code and r.year=year;
while counter < 53 do
  insert into flight(week,schedule)
    select counter,s.id
    from weekly_schedule s
    where s.dep_time=dep_time and s.day=day and s.year=year and s.route=(
      select r.id
      from route r
      where r.arr_airport=arr_code and r.dep_airport=dep_code and r.year=year);
  set counter=counter+1;
end while;
end;//
delimiter ;

create table passenger(
passport integer not null,
name varchar(30),
constraint pk_passenger primary key(passport));

create table contact(
passport integer not null,
phone bigint not null,
email varchar(30) not null,
constraint foreign key(passport) references passenger(passport),
constraint pk_contact primary key(passport));

create table reservation(
id integer not null auto_increment,
flight integer,
contact integer,
num_of_passengers integer default 0,
constraint foreign key(contact) references contact(passport),
constraint foreign key(flight) references flight(id),
constraint pk_reservation primary key(id));

create table booking(
reservation integer,
price double(8,3),
card_number bigint,
holder_name varchar(30),
unique key unique_card_num (card_number),
constraint foreign key(reservation) references reservation(id) on delete cascade,
constraint pk_booking primary key(reservation));

create table tickets(
passenger integer,
reservation integer,
ticket_number integer,
unique key unique_ticket (ticket_number),
constraint foreign key(passenger) references passenger(passport),
constraint foreign key(reservation) references reservation(id) on delete cascade,
constraint pk_tickets primary key(passenger,reservation));

delimiter //
create function calculateFreeSeats(flight_num integer)
returns integer
deterministic
begin
declare occupied_seats integer default 0;
set occupied_seats = (select count(passenger) from tickets t inner join reservation r on t.reservation=r.id and (t.ticket_number is not null) and (r.flight=flight_num) and (r.contact is not null));
return(40-occupied_seats);
end;//

create function calculatePrice(flight_num integer)
returns double(8,3)
deterministic
begin
declare route_price double(8,3);
declare factor double(4,2);
declare profit_factor double(4,2);
declare num_of_bookings integer;
declare day varchar(10);
declare year integer;
set day = (select s.day from weekly_schedule s where s.id=(
    select f.schedule from flight f where f.id=flight_num));
set year = (select s.year from weekly_schedule s where s.id=(
    select f.schedule from flight f where f.id=flight_num));
set route_price = (select r.price from route r where r.id=(
  select s.route from weekly_schedule s where s.id=(
    select f.schedule from flight f where f.id=flight_num)));
set factor = (select d.factor from day d where d.name=day and d.year=year);
set profit_factor = (select y.profit_factor from year y where y.num=year);
set num_of_bookings = 40 - calculateFreeSeats(flight_num);
return(route_price * factor * profit_factor * (num_of_bookings + 1) / 40);
end;//

create trigger issueTicket
after insert on booking
for each row
begin
declare res_num integer;
set res_num = NEW.reservation;
update tickets t
set t.ticket_number = floor(rand()*(9999-0000+1))+0000
where t.reservation = res_num;
end;//
delimiter ;

delimiter //
create procedure addPassenger(in res_num integer, in passport integer, in name varchar(30))
begin
declare counter int unsigned default 1; /*has to be right after the BEGIN statement*/
if exists(select 1 from reservation r where r.id=res_num) then
  if exists(select 1 from booking b where b.reservation=res_num) then
    select "The booking has already been payed and no futher passengers can be added." as "ERROR MESSAGE";
  else
    if !exists(select 1 from passenger p where p.passport=passport and p.name=name) then
      insert into passenger(passport,name) values(passport,name);
    end if;
    update reservation r set r.num_of_passengers=r.num_of_passengers+1 where r.id=res_num; /*faltava aixo*/
    insert into tickets(reservation,passenger) values(res_num,passport);
    select "Passenger information added to the system." as "MESSAGE";
  end if;
else
  select "The given reservation number does not exist." as "ERROR MESSAGE";
end if;
end;//
delimiter ;

delimiter //
create procedure addContact(in res_num integer, in passport integer, in email varchar(30), in phone bigint)
begin
if exists(select 1 from reservation r where r.id=res_num) then
  if exists(select 1 from tickets t where t.reservation=res_num and t.passenger=passport) then
    if not exists(select 1 from contact c where c.passport=passport) then
      insert into contact(passport,phone,email) values(passport,phone,email);
    end if;
    update reservation r set r.contact=passport where r.id=res_num;
    select "Contact information added to the system." as "MESSAGE";
  else
    select "The person is not a passenger of the reservation." as "ERROR MESSAGE";
  end if;
else
  select "The given reservation number does not exist." as "ERROR MESSAGE";
end if;
end;//
delimiter ;

delimiter //
create procedure addPayment(in res_num integer, in holder_name varchar(30), in card_number bigint)
begin
if exists(select 1 from reservation r where r.id=res_num) then
  begin
  declare free_seats integer default 0;
  declare num_pass integer default 0;
  declare flight_num integer default 0;
  set flight_num = (select r.flight from reservation r where r.id=res_num);
  set num_pass = (select r.num_of_passengers from reservation r where r.id=res_num);
  set free_seats = (calculateFreeSeats(flight_num));
  if ((select r.contact from reservation r where r.id=res_num) is null) then
    select "The reservation has no contact yet." as "ERROR MESSAGE";
  elseif (num_pass>free_seats) then
      select "There are not enough seats available on the flight anymore, deleting reservation." as "ERROR MESSAGE";
      delete from reservation where id=res_num;
  else
    insert into booking(reservation,card_number,holder_name, price)
    values(res_num,card_number,holder_name, calculatePrice(flight_num));
    select "Payment information added to the system." as "MESSAGE";
  end if;
  end;
else
  select "The given reservation number does not exist." as "ERROR MESSAGE";
end if;
end;//
delimiter ;

delimiter //
create procedure addReservation(in dep_code varchar(3), in arr_code varchar(3),
  in year integer, in week integer, in day varchar(10), in dep_time time,
  in num_of_passengers integer, out res_num integer)
begin
declare route_exists boolean default false;
declare date_exists boolean default false;
set route_exists = exists(select 1 from route r where r.arr_airport=arr_code and r.dep_airport=dep_code and r.year=year);
set date_exists = exists(select 1 from weekly_schedule s where s.dep_time=dep_time and s.day=day and s.year=year);

if route_exists=1 and date_exists=1 then
  begin
  declare flight_num integer default 0;
  set flight_num = (select f.id from flight f where f.week=week and f.schedule=(
    select s.id from weekly_schedule s where s.dep_time=dep_time and s.day=day and s.year=year and s.route=(
      select r.id from route r where r.arr_airport=arr_code and r.dep_airport=dep_code and r.year=year)));
  if num_of_passengers>calculateFreeSeats(flight_num) then
    select "There are not enough seats available on the chosen flight." as "ERROR MESSAGE";
  else
    begin
    set res_num = (floor(rand()*(9999-0000+1))+0000);
    /*insert into reservation(id,num_of_passengers,flight) values(res_num,num_of_passengers,flight_num);*/
    insert into reservation(id,num_of_passengers,flight) values(res_num,0,flight_num);
    select "Reservation added to the system." as "MESSAGE";
    end;
  end if;
  end;
else
  select "There exist no flight for the given route, date and time." as "ERROR MESSAGE";
end if;
end;//
delimiter ;

create view allFlights as
  select f.id as 'flight_number',
  a1.name as 'departure_city_name',
  a2.name as 'destination_city_name',
  s.dep_time as 'departure_time',
  s.day as 'departure_day',
  f.week as 'departure_week',
  s.year as 'departure_year',
  calculateFreeSeats(f.id) as 'nr_of_free_seats',
  calculatePrice(f.id) as 'current_price_per_seat'
  from flight f inner join weekly_schedule s on f.schedule = s.id
  inner join route r on r.id = s.route
  inner join airport a1 on a1.code = r.dep_airport
  inner join airport a2 on a2.code = r.arr_airport
  order by f.id asc;

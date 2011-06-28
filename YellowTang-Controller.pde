
//**************** Yellow Tang AquaController ****************
//Version :   1.0
//DATE :      27 june 2011
//AUTHOR :    Catherine Reymond http://wismie.wordpress.com - wismie@gmail.com
//LICENCE :   GNU GPL 3.0
//DONE :      RTC/TEMP/SD LOGGER/GLCD SCREEN/ Addition of ethernet Shield + SD card, Pachube Connection w/Twitter, relays
//WIP :       servo for water movement in aquarium, various level controls
//FUTURE:     menus, buttons, servo motor for pumps, alarms, water change
//*************************************************************

//**************** Libraries ****************

#include <Wire.h> //for the clock
#include <Time.h> //for the Clock
#include <DS1307RTC.h>  // a basic DS1307 library that returns time as a time_t
#include <glcd.h> //graphical Screen
#include <Streaming.h> //streaming with <<
#include <SD.h>
#include "fonts/allFonts.h"         //GLCD system and arial14 fonts are used
#include "bitmaps/allBitmaps.h"   //GLCD all images in the bitmap dir 
#include <SPI.h> // for ethernet shield-SD card
#include <Ethernet.h> //for ethernet shield- SD Card
#include <EthernetDNS.h> // for Twitter
#include <Twitter.h> // for Twitter
#include <Servo.h>  // servo motor for pump

//**************** Defines PIN & Variables ****************
#define Ventilator 22 //test with panasonic which is always on then high = on low = off
#define LevelControl 15 //pin to check the level control in the skimmer
#define OpticalControl 0 // optical sensor


//RELAYS
#define Relay1 38 // first relay on PIN 38  RED
#define Relay2 41 // second relay on PIN 39 BLUE
#define Relay3 39 // yellow
#define Relay4 40 //green


//TIMERS ** defines when relays are on or off ** (uses shortnow() format so : 15:49)
String RelayTimer1_Begin = "11:00";
String RelayTimer2_Begin = "11:30";
String RelayTimer3_Begin = "12:00";
String RelayTimer4_Begin = "15:20";
String RelayTimer1_End = "22:00";
String RelayTimer2_End = "22:15";
String RelayTimer3_End = "22:30";
String RelayTimer4_End = "15:30";

//SD Variables
const int chipSelect = 4; //for SD on Ethernet Shield BUT INPUT 53 must not be used
Sd2Card card; //Variables to check SD capacity if needed (check CardInfo Script)
SdVolume volume;
SdFile root;
char filenameTemp[100]; //to hold filenames converted to char to open filename
char filenameEvents[100];//to hold filenames converted to char to openfilename
boolean Logging ; //defines if SD logging works or not

//Date and Time Management
String TodayTempFileName; //logs the temp
String TodayEventFileName; //logs the events

//Temp Average calcs
const int NumberValuesAVG = 100; // Defines how many values the array will keep for the temp averages
double ReadingsAVG[NumberValuesAVG]; //array that contains the values
int index = 0;
double total = 0;
double average = 0;
boolean ventStatus = false; //defines if the vent is on or not

//Temp values
#define LM35DZ PIN 1 //LM35DZ temp reading
double temp; //temperature var
double tempL; //temp from LM35DZ
double tempDebug;
double currentTemp = 0; //temporary Temp Variable 
double HighLow[] = {
  0,99,1};// HighLow[0]=High, HighLow[1]=low, HighLow[2]=AVG
double ventLimit[]  = {
  26.0, 25.5} 
; //first is the threshold to start vent, [0], second to stop vent [1] 

//SystemAlarms
boolean alarms; //check if there are any alarms on the system
int alarmsInt; //Number of Alarms

//Code Running Intervals 
long LGpreviousMillis = 0;
long SHpreviousMillis = 0;
long VLGpreviousMillis = 0;
// Code Running intervals
long LGinterval = 10000; //interval at which the serial data is updated, here 10 secs
long SHinterval = 500; //actions to run more often (every sec)
long VLGinterval = 600000; //very long interval, mainly for event and temp logging on SD card. Here 10 mins

//Ethernet Shield Variables
// Enter a MAC address and IP address for your controller below.
// The IP address will be dependent on your local network:
byte mac[] = {  
  0x90, 0xA2, 0xD4, 0x00, 0x40, 0xC0 }; // shield MAC Address
byte ip[] = { 
  192,168,1,177 }; //local IP on network
byte gateway[] = { 
  192,168,1,1};	
byte subnet[] = { 
  255, 255, 255, 0 };
Server server(80); //listens on port 80 for web access

// Your Token to Tweet (get it from http://arduino-tweet.appspot.com/)
Twitter twitter("17323869-in6ypJmup7ScC1WrqB95npkq4pNKMLx9nacffTmGC");
String Twittermsg;
char msgtemp[10]; //to convert currentTemp in char
String TwitterRecipient; //defines who will be the direct recipient of the twitter DM

// Servo Management
Servo myservo;  // create servo object to control a servo 
// a maximum of eight servo objects can be created 

//*****************************************
//**************** SETUP *****************  
//*****************************************
void setup()
{//BEGIN SETUP BRACKET

  // start serial port at 9600 bps:
  Serial.begin(9600);

  // Start Ethernet Shield

  Ethernet.begin(mac, ip, gateway, subnet);
  server.begin(); //initialize web server

  //Clear Screen

    GLCD.Init() ; 
  GLCD.SelectFont(SystemFont5x7); // font for the default text area
  GLCD << "...Starting up..." << endl;

  //Init variables
  pinMode (Ventilator, OUTPUT); //defines the ventilator is an output 
  digitalWrite(Ventilator, LOW); // ventilator output is off
  //HighLow[2] = Thermister(analogRead(0)); //sets the AVG value if Thermister is on
  //HighLow[2] = TempLM35(analogRead(1)); //Set the AVF value for the LM35
  HighLow[2] = TempLM35(); //Set the AVF value for the LM35
  ventStatus = 0; //stops the vents by default
  pinMode (LevelControl, INPUT); //Level Control is an input


  //New RTC functions

  setSyncProvider(RTC.get);   // the function to get the time from the RTC
  GLCD.ClearScreen();
  if(timeStatus()!= timeSet)  {
    Serial << "Unable to sync with the RTC" << endl;
    GLCD << "RTC not found!" << endl; 
    delay (1000);
  }
  else {
    Serial << "RTC has set the system time" << endl;  
    GLCD << "RTC sets the time" << endl;   
    delay (1000); 
  }


  // ******* RELAY MANAGEMENT *******

  pinMode(Relay1, OUTPUT);
  pinMode(Relay2, OUTPUT);
  pinMode(Relay3, OUTPUT);
  pinMode(Relay4, OUTPUT);

  digitalWrite(Relay1, LOW); //Deactivate Relay1 (LOW = OFF et HIGH = ON)
  digitalWrite(Relay2, LOW);//
  digitalWrite(Relay3, LOW);
  digitalWrite(Relay4, LOW);

  // ******* SD Logging *******
  Serial << "Initializing SD card...";
  GLCD << "Initializing SD card" << endl;
  // make sure that the default chip select pin is set to
  // output, even if you don't use it:
  pinMode(53, OUTPUT);
  // see if the card is present and can be initialized:
  if (!SD.begin(chipSelect)) {
    Serial << "Card failed, or not present"<< endl;
    GLCD << "Card failed, or not present" <<endl;
    delay (5000);
    // don't do anything more:
    Logging = false;
    return;
  }
  Serial << "card initialized." << endl;
  PrintDots();
  GLCD  << "card OK!" << endl;
  Logging = true;
  delay (2000);

  SDcardCheck();
  TodayTempFile();
  TodayEventFile();

  GLCD.ClearScreen();
  GLCD.GotoXY(0,0);

  // Servo

  myservo.attach(9);  // attaches the servo on pin 9 to the servo object 

} //END SETUP BRACKET

//***************************************
// **************** LOOP ****************
//**************************************
void loop()
{//BEGIN LOOP BRACKET

  //WebServer();

  //Servo Management
  Servo1();


  //**** TEMPERATURE ****
  currentTemp = TempLM35(); //read from LM35

    //**** Actions do to in a short interval (here every 1 secs)
  if (millis() - SHpreviousMillis > SHinterval) {
    SHpreviousMillis = millis();    

    //print Temp on LCD
    //GLCD.ClearScreen();
    GLCD.GotoXY(0,0);
    //GLCD.DrawBitmap(ventilo,64,0);
    GLCD.SelectFont(Arial_bold_14);
    GLCD << _FLOAT(currentTemp,1) << "c "; //show current temp _FLOAT(xyz,1) is to show 1 decimal only on screen
    GLCD << ShortToday() << " " << ShortNow() << endl;
    GLCD.SelectFont(SystemFont5x7);
    GLCD << "L:" << _FLOAT(HighLow[1],1) << " H:" << _FLOAT(HighLow[0],1) << " A:" << _FLOAT(HighLow[2],1) << endl; 
    if (ventStatus) {
      GLCD << "V:ON";
    }
    else {
      GLCD << "V:OFF";
    }
    if (analogRead(LevelControl)){
      GLCD << " SKL:HIGH"<< endl; //SKL = Skimmer Level
    }
    else{
      GLCD << " SKL:LOW"<< endl;
    }

    if (currentTemp < HighLow[1] )
    {
      HighLow[1] = currentTemp;
    }
    else if (currentTemp > HighLow[0]){

      HighLow[0] = currentTemp;    
    }

    GLCD << "R1:" << digitalRead(Relay1) << " R2:"<< digitalRead(Relay2) << " R3:"<< digitalRead(Relay3) << " R4:" << digitalRead(Relay4) << endl;

    // Test OpticalControl 14

    //GLCD << "Test : " << analogRead(OpticalControl) << endl;

  }   // end short interval actions

  //**** Actions with do every X seconds (defined by the Interval value  **** (here every 10 secs)
  if (millis() - LGpreviousMillis > LGinterval) {
    // save the last time serialPrint was done
    LGpreviousMillis = millis();   


    //Calculate the AVG to avoid a calc that is too quick
    //Average calculation
    total= total - ReadingsAVG[index];
    ReadingsAVG[index]= currentTemp;
    total = total + ReadingsAVG[index];
    index = index + 1;
    //Calculates the AVG when the number of readings is reached 
    if (index >=NumberValuesAVG){
      index = 0;
      HighLow[2]=total/NumberValuesAVG;
    }

    if (currentTemp >= ventLimit[0] && ventStatus == 0){ //put Ventilator on if temp > 26 and if vent is off
      digitalWrite(Ventilator, HIGH); 
      ventStatus = true; //defines that the vent is running
      GLCD << "T:" << currentTemp << " >=LM: " << ventLimit[0] << endl ;
      GLCD << "Vent Starting" << endl;

      Serial << Today() << " " << Now() <<  " Temp : " << currentTemp << " Ventilator Starting" << endl; 
      File dataEvents = SD.open(filenameEvents, FILE_WRITE);
      dataEvents << Today() << " " << Now() <<  " Temp : " << currentTemp << " Ventilator Starting" << endl;
      Logging = true;
      dataEvents.close();
      delay (10000);

    }
    else if (currentTemp <= ventLimit[1] && ventStatus == 1) { // puts ventilator down if temp lower than 25.5 and if the vent is on
      digitalWrite (Ventilator, LOW);
      ventStatus = false; //defines that the vent is not running
      GLCD << "T:" << currentTemp << " <=LM: " << ventLimit[1] << endl;
      GLCD << "Vent Stopping" << endl;  
      Serial << Today() << " " << Now() <<" Temp : " << currentTemp << " Ventilator Stopping" << endl;
      File dataEvents = SD.open(filenameEvents, FILE_WRITE);
      //GLCD << "Writing Event to SD" << endl;
      Logging = true;
      dataEvents << Today() << " " << Now() <<" Temp : " << currentTemp << " Ventilator Stopping" << endl;
      dataEvents.close(); 
      delay (10000);
    }

    //RELAYS 
    //Check if relays must be on or off
    RelayTimer(Relay1);
    RelayTimer(Relay2);
    RelayTimer(Relay3);
    RelayTimer(Relay4);

    //**** LOGGING *****
    // Print values on Serial for debugging & future logging on PC

    // Prints the date
    Serial << Today() << " " << Now() << " |L " << HighLow[1] << " |H " << HighLow[0] <<" |C " << currentTemp << " |A " << HighLow[2] << "|V "; 
    if (ventStatus) {
      Serial << "ON";
    }
    else {
      Serial << "OFF";
    }
    if (analogRead(LevelControl)){
      Serial << " |L ON "<< endl;
    }
    else{
      Serial << " |L OFF "<< endl;
    }

    Serial << "R1:" << digitalRead(Relay1) << " R2:"<< digitalRead(Relay2) << " R3:"<< digitalRead(Relay3) << " R4:" << digitalRead(Relay4) << endl;

    //**** Actions with do every X seconds (defined by the Interval value  **** (here every 10 mins)
    if (millis() - VLGpreviousMillis > VLGinterval) {
      // save the last time serialPrint was done
      VLGpreviousMillis = millis();   

      //******* DataLogger *********

      // open the file. note that only one file can be open at a time,
      // so you have to close this one before opening another.
      // String TodayTempFileName; //logs the temp
      //String TodayEventFileName; //logs the events (for future use, not yet used)
      Serial << "test 10 mins status : ";

      if (SD.exists(filenameTemp)){
        Serial << "The file exists !" <<endl;
      }
      else {
        Serial << "the file does not exist !" << endl;  
      }

      File dataFile = SD.open(filenameTemp, FILE_WRITE);
      // if the file is available, write to it:
      if (dataFile) {
        dataFile << Today() << " " << Now () << " |L " << HighLow[1] << " |H " << HighLow[0] <<" |C " << currentTemp << " |A " << HighLow[2] << "|V "; 
        //GLCD << "Writing Temp Stats to SD" << endl;
        delay (5000);
        if (ventStatus) {
          dataFile << "ON";
        }
        else {
          dataFile << "OFF";
        }
        if (analogRead(LevelControl)){
          Serial << " |L ON "<< endl;
        }
        else{
          Serial << " |L OFF "<< endl;
        }  
        Logging = true;
        dataFile.close(); //closing the file to allow other logs to be created
      }
      // if the file isn't open, pop up an error:
      else {
        Serial << "error opening log file : " << filenameTemp << endl;
        //GLCD << "Error while writing Temp to SD :" << filenameTemp << endl;
        Logging = false;
      } 

      TwitterRecipient = "d pachtweet "; //sends direct message to pachtweet
      Twittermsg = TwitterRecipient;
      Twittermsg += "set 28727 ";
      //Serial << "Current Temp : " << currentTemp << endl; //debug
      Twittermsg += dtostrf(currentTemp, 4, 2, msgtemp); //convert double value (currentTemp) to char
      //Serial << "Twitter Message : "<< Twittermsg << endl;  //debug
      SendTwitter(Twittermsg); //sends update to Twitter    

    }


  }
} //END LOOP BRACKET//






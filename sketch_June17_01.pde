
//**************** Yellow Tang AquaController ****************
//Version :   1.0
//DATE :      17 june 2011
//AUTHOR :    Catherine Reymond http://wismie.wordpress.com
//LICENCE :   GNU GPL 3.0
//DONE :      RTC/TEMP/SD LOGGER/GLCD SCREEN
//WIP :       relays
//FUTURE:     menus, buttons, servo motor for pumps, alarms, water change
//*************************************************************


//**************** Libraries ****************

#include <LiquidCrystal.h>
#include <EEPROM.h>
#include <math.h>
#include <Wire.h> //for the clock
#include <Time.h> //for the Clock
#include <DS1307RTC.h>  // a basic DS1307 library that returns time as a time_t
#include <glcd.h> //graphical Screen
#include <Streaming.h> //streaming with <<
#include <SD.h>
#include "fonts/allFonts.h"         //****GLCD*****system and arial14 fonts are used
#include "bitmaps/allBitmaps.h"   //****GLCD***** all images in the bitmap dir 

//**************** Defines PIN & Variables ****************
#define Ventilator 22 //test with panasonic which is always on then high = on low = off
#define LevelControl 15 //pin to check the level control in the skimmer
#define OpticalControl 0 // optical sensor
#define Relay1 38 // first relay on PIN 38
#define Relay2 39 // second relay on PIN 39
#define Relay3 40 //
#define Relay4 41

//SD Variables
const int chipSelect = 53; /*On the Arduino Mega, this is 50 (MISO), 51 (MOSI), 52 (SCK), and 53 (SS).*/
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

//*****************************************
//**************** SETUP *****************  
//*****************************************
void setup()
{//BEGIN SETUP BRACKET

  // start serial port at 9600 bps:
  Serial.begin(9600);

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

  digitalWrite(Relay1, LOW); //activate Relay1 (LOW = OFF et HIGH = ON)
  digitalWrite(Relay2, LOW);//activate Relay2
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
    Serial << "Card failed, or not present";
    GLCD << "Card failed, or not present";
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

} //END SETUP BRACKET

//***************************************
// **************** LOOP ****************
//**************************************
void loop()
{//BEGIN LOOP BRACKET

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
      GLCD << "Writing Event to SD" << endl;
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
      GLCD << "Writing Event to SD" << endl;
      Logging = true;
      dataEvents << Today() << " " << Now() <<" Temp : " << currentTemp << " Ventilator Stopping" << endl;
      dataEvents.close(); 
      delay (10000);
    }

    digitalWrite(Relay1, HIGH); //activate Relay1 (LOW = OFF et HIGH = ON)
    digitalWrite(Relay2, HIGH);//activate Relay2
    digitalWrite(Relay3, HIGH);
    digitalWrite(Relay4, HIGH);

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


    //**** Actions with do every X seconds (defined by the Interval value  **** (here every 10 mins)
    if (millis() - VLGpreviousMillis > VLGinterval) {
      // save the last time serialPrint was done
      VLGpreviousMillis = millis();   

      //******* DataLogger *********

      // open the file. note that only one file can be open at a time,
      // so you have to close this one before opening another.
      // String TodayTempFileName; //logs the temp
      //String TodayEventFileName; //logs the events (for future use, not yet used)
      Serial << "test 10 mins"  << endl;

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

    }


  }
} //END LOOP BRACKET//

//**************************
// ****** FUNCTIONS ********
// **************************

//Temperature

double TempLM35() {//calc temp from LM35
  int i; 
  int sval = 0;
  double Temp;
  for (i = 0; i<100; i++){
    sval = sval + analogRead(1);
  } //take 100 measures (sensor smoothing)
  sval = sval/100;
  Temp = 5*(float(sval)* 100/1024.0) ;
  return Temp;  
}

//Time and Date management

void printDayName(byte d)
{
  switch (d) {
  case 1:
    Serial << "MON";
    break;
  case 2:
    Serial<< "TUE";
    break;
  case 3:
    Serial << "WED";
    break;
  case 4:
    Serial << "THU";
    break;
  case 5:
    Serial << "FRI";
    break;
  case 6:
    Serial << "SAT";
    break;
  case 7:
    Serial << "SUN";
    break;
  default:
    Serial << "???";
  }
}
String Today (){ //displays date in full format : 07.06.2011
  String CurrentDate;
  if (day() < 10){
    CurrentDate = "0";
    CurrentDate += day();
  }
  else {
    CurrentDate += day();
  }	
  CurrentDate += ".";
  if (month () < 10)
    CurrentDate += "0";
  CurrentDate += month();
  CurrentDate += ".";
  CurrentDate += year();
  return CurrentDate;
}

String ShortToday(){ //diplays the date in short format : 06/07
  String ShortCurrentDate;
  if (day() < 10){
    ShortCurrentDate = "0";
    ShortCurrentDate += day();
  }
  else {
    ShortCurrentDate += day();
  }	
  ShortCurrentDate += "/";
  if (month () < 10)
    ShortCurrentDate += "0";
  ShortCurrentDate += month();
  return ShortCurrentDate;
}

String Now () { //displays the time in full format : 15:48:33
  String CurrentTime;
  if (hour()< 10){
    CurrentTime = "0";
    CurrentTime += hour();
  }
  else {
    CurrentTime = hour();
  }
  CurrentTime += ":";
  if (minute() < 10){
    CurrentTime += "0";
  }
  CurrentTime += minute();
  CurrentTime += ":";
  if (second()<10){
    CurrentTime += "0";
  }
  CurrentTime += second();
  return CurrentTime;
}

String ShortNow(){ //displays the time in short format : 15:49
  String ShortCurrentTime;
  if (hour()< 10){
    ShortCurrentTime = "0";
    ShortCurrentTime += hour();
  }
  else {
    ShortCurrentTime = hour();
  }
  ShortCurrentTime += ":";
  if (minute() < 10){
    ShortCurrentTime += "0";
  }
  ShortCurrentTime += minute();  
  return ShortCurrentTime;
}

String TodayTempFile () {
  TodayTempFileName = year();
  TodayTempFileName += month();
  TodayTempFileName += day();
  TodayTempFileName += "T.TXT";
  //Conversion to char file type
  TodayTempFileName.toCharArray(filenameTemp, 100);
  Serial << "Temp file name : " << TodayTempFileName << endl;
  return filenameTemp;
  return TodayTempFileName;
}

String TodayEventFile () {
  TodayEventFileName =  year();
  TodayEventFileName += month();
  TodayEventFileName += day();
  TodayEventFileName += "E.TXT";
  //Conversion to char file type
  TodayEventFileName.toCharArray(filenameEvents, 100);
  Serial << "Event file name : " << TodayEventFileName << endl;
  return TodayTempFileName;
  return filenameEvents; 
}

//LCD Screen Management
void PrintDots(){//prints 10 dots on LCD screen
  int i;
  for (i = 0; i<10; i++){
    GLCD << "." ;
    delay (200);
  };
}

//SD management

void SDcardCheck(){
  // we'll use the initialization code from the utility libraries
  // since we're just testing if the card is working!
  if (!card.init(SPI_HALF_SPEED, chipSelect)) {
    Serial.println("initialization failed. Things to check:");
    Serial.println("* is a card is inserted?");
    Serial.println("* Is your wiring correct?");
    Serial.println("* did you change the chipSelect pin to match your shield or module?");
    return;
  } 
  else {
    Serial.println("Wiring is correct and a card is present."); 
  }

  // print the type of card
  Serial.print("\nCard type: ");
  switch(card.type()) {
  case SD_CARD_TYPE_SD1:
    Serial.println("SD1");
    break;
  case SD_CARD_TYPE_SD2:
    Serial.println("SD2");
    break;
  case SD_CARD_TYPE_SDHC:
    Serial.println("SDHC");
    break;
  default:
    Serial.println("Unknown");
  }

  // Now we will try to open the 'volume'/'partition' - it should be FAT16 or FAT32
  if (!volume.init(card)) {
    Serial.println("Could not find FAT16/FAT32 partition.\nMake sure you've formatted the card");
    return;
  }

  // print the type and size of the first FAT-type volume
  long volumesize;
  Serial.print("\nVolume type is FAT");
  Serial.println(volume.fatType(), DEC);
  Serial.println();

  volumesize = volume.blocksPerCluster();    // clusters are collections of blocks
  volumesize *= volume.clusterCount();       // we'll have a lot of clusters
  volumesize *= 512;                            // SD card blocks are always 512 bytes
  Serial.print("Volume size (bytes): ");
  Serial.println(volumesize);
  Serial.print("Volume size (Kbytes): ");
  volumesize /= 1024;
  Serial.println(volumesize);
  Serial.print("Volume size (Mbytes): ");
  volumesize /= 1024;
  Serial.println(volumesize);

  Serial.println("\nFiles found on the card (name, date and size in bytes): ");
  root.openRoot(volume);

  // list all files in the card with date and size
  root.ls(LS_R | LS_DATE | LS_SIZE);  
} 

//NOTES AND SUCH
// Ventilator is put on Pin 22 - no PWM so far
// Temperature on analog 0 (no need to declare)
// SDA 20 //IC22 ports clock (no need to declare)
// SDC 21 //IC21 ports clock (no need to declare)
// SDA 15 //level control of reverse osmosis control is pin 15













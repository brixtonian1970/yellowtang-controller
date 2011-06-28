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

void SendTwitter(String msg) 
{
  //Serial << "Message to send : "<< msg << endl; //for debugging
  char twittermsg[30];
  msg.toCharArray(twittermsg, 30);
  //Serial << "Message ready to send : "<< twittermsg << endl; //for debugging
  //Serial << "Old Message : "<< temptwittermsg << endl; //for debugging

  Serial.println("connecting ...");

  if (twitter.post(twittermsg)) {
    // Specify &Serial to output received response to Serial.
    // If no output is required, you can just omit the argument, e.g.
    // int status = twitter.wait();
    int status = twitter.wait(&Serial);
    if (status == 200) {
      Serial.println("OK.");
    } 
    else {
      Serial.print("failed : code ");
      Serial.println(status);
    }
  } 
  else {
    Serial.println("connection failed.");
  }


} 

void WebServer(){
  //Listens on Web Server TO CHANGE IN A FUNCTION LATER ON AND CHANGE THE CONTENT
  // listen for incoming clients
  Client client = server.available();
  if (client) {
    // an http request ends with a blank line
    boolean currentLineIsBlank = true;
    while (client.connected()) {
      if (client.available()) {
        char c = client.read();
        // if you've gotten to the end of the line (received a newline
        // character) and the line is blank, the http request has ended,
        // so you can send a reply
        if (c == '\n' && currentLineIsBlank) {
          // send a standard http response header
          client.println("HTTP/1.1 200 OK");
          client.println("Content-Type: text/html");
          client.println();

          // output the value of each analog input pin
          for (int analogChannel = 0; analogChannel < 6; analogChannel++) {
            client.print("analog input ");
            client.print(analogChannel);
            client.print(" is ");
            client.print(analogRead(analogChannel));
            client.println("<br />");
          }
          break;
        }
        if (c == '\n') {
          // you're starting a new line
          currentLineIsBlank = true;
        } 
        else if (c != '\r') {
          // you've gotten a character on the current line
          currentLineIsBlank = false;
        }
      }
    }
    // give the web browser time to receive the data
    delay(1);
    // close the connection:
    client.stop();
  } // Stop server function 
}

void Servo1(){ //function to manage servo Sweep
  int pos = 0;    // variable to store the servo position 
  for(pos = 0; pos < 180; pos += 1)  // goes from 0 degrees to 180 degrees 
  {                                  // in steps of 1 degree 
    myservo.write(pos);              // tell servo to go to position in variable 'pos' 
    delay(15);                       // waits 15ms for the servo to reach the position 
  } 
  for(pos = 180; pos>=1; pos-=1)     // goes from 180 degrees to 0 degrees 
  {                                
    myservo.write(pos);              // tell servo to go to position in variable 'pos' 
    delay(15);                       // waits 15ms for the servo to reach the position 
  } 
}

void RelayTimer(int RelayNumber)
{
  String RelayAlarm_Begin;
  String RelayAlarm_End;

  switch (RelayNumber){
  case Relay1:
    RelayAlarm_Begin = RelayTimer1_Begin;
    RelayAlarm_End = RelayTimer1_End;
    break;
  case Relay2:
    RelayAlarm_Begin = RelayTimer2_Begin;
    RelayAlarm_End = RelayTimer2_End;
    break;
  case Relay3:
    RelayAlarm_Begin = RelayTimer3_Begin;
    RelayAlarm_End = RelayTimer3_End;
    break;
  case Relay4:
    RelayAlarm_Begin = RelayTimer4_Begin;
    RelayAlarm_End = RelayTimer4_End;
    break;
  }

  if (RelayAlarm_Begin.equals(ShortNow())){ 
    digitalWrite(RelayNumber, HIGH);
  }
  else if (RelayAlarm_End.equals(ShortNow())){
    digitalWrite(RelayNumber, LOW);
  }

}
//NOTES AND SUCH
/* 
 
 Ventilator is put on Pin 22 - no PWM so far
 Temperature on analog 0 (no need to declare)
 SDA 20 //IC22 ports clock (no need to declare)
 SDC 21 //IC21 ports clock (no need to declare)
 SDA 15 //level control of reverse osmosis control is pin 15
 for SD external module :const int chipSelect = 53; /*On the Arduino Mega, this is 50 (MISO), 51 (MOSI), 52 (SCK), and 53 (SS).
 
 
 
 
 
 
 
 */
















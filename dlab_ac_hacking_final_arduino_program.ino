#include <max6675.h>
#include <SoftWire.h>
#include <SHT31_SW.h>
#include <OneWire.h>
#include <DallasTemperature.h>

// OneWire Tempurature Sensor:
#define ONE_WIRE_BUS 3
OneWire oneWire(ONE_WIRE_BUS);
DallasTemperature sensors(&oneWire);

// Humidity and Tempurature Sensors:
SoftWire sw1(8, 9); // SDA, SCL
SHT31_SW sht1(0x44, &sw1);
SoftWire sw2(6, 7); // SDA, SCL
SHT31_SW sht2(0x44, &sw2);
SoftWire sw3(4, 5); // SDA, SCL
SHT31_SW sht3(0x44, &sw3);


// thermocouples
int thermoSO = 12;
int thermoCLK = 13;
int thermoCS1 = 10;
int thermoCS2 = 11;
MAX6675 thermocouple1(thermoCLK, thermoCS1, thermoSO);
MAX6675 thermocouple2(thermoCLK, thermoCS2, thermoSO);

// // Flow Sensor:
// volatile int pulseCount = 0;
// const int flowSensorPin = 2; // Yellow wire
// float flowRate = 0.0;
// unsigned int flowmL = 0;
// unsigned long totalmL = 0;
// unsigned long oldTime = 0;
// void pulseCounter() {
//   pulseCount++; // Increment pulse count
// }

void setup() {
  // start serial port
  Serial.begin(9600);
  delay(500);

  // begin flow sensor
  // pinMode(flowSensorPin, INPUT);
  // attachInterrupt(digitalPinToInterrupt(flowSensorPin), pulseCounter, RISING);

  // begin temp sensors
  sensors.begin();    

  // Start the software I2C busses
  sw1.begin();
  sw2.begin();
  sw3.begin();
  
  // Initialize sht sensors
  if (!sht1.begin()) {
    Serial.println("sht1 not found!");
  }
  if (!sht2.begin()) {
    Serial.println("sht2 not found!");
  }
  if (!sht3.begin()) {
    Serial.println("sht3 not found!");
  }
}

void loop(void) {
  // if ((millis() - oldTime) > 1000) { // Measure every second
  //   detachInterrupt(digitalPinToInterrupt(flowSensorPin)); // Stop interrupts while calculating
    
  //   // Formula: Flow Rate (L/min) = Frequency / Calibration Factor (7.5 for YF-S201)
  //   flowRate = ((1000.0 / (millis() - oldTime)) * pulseCount) / 7.5;
  //   oldTime = millis();
    
  //   flowmL = (flowRate / 60) * 1000;
  //   totalmL += flowmL;
    
  //   pulseCount = 0; // Reset pulse count
  //   attachInterrupt(digitalPinToInterrupt(flowSensorPin), pulseCounter, RISING); // Resume
  // }

  // read data from sensors
  sht1.read();
  sht2.read();
  sht3.read();

  float stemp1 = sht1.getTemperature();
  float stemp2 = sht2.getTemperature();
  float stemp3 = sht3.getTemperature();
  float shumid1 = sht1.getHumidity();
  float shumid2 = sht2.getHumidity();
  float shumid3 = sht3.getHumidity();

  if (!sht1.isConnected()) {
    stemp1 = -100.00;
    shumid1 = -100.00;
  }
  if (!sht2.isConnected()) {
    stemp2 = -100.00;
    shumid2 = -100.00;
  }
  if (!sht3.isConnected()) {
    stemp3 = -100.00;
    shumid3 = -100.00;
  }

  sensors.requestTemperatures();
  float tempC = sensors.getTempCByIndex(0);

  float thermo1 = thermocouple1.readCelsius();
  float thermo2 = thermocouple2.readCelsius();

  delay(1000); // MUST BE >= 250ms

  Serial.print("temp1:");
  Serial.print(tempC);

  Serial.print(", thermo1:"); 
  Serial.print(thermo1);
  Serial.print(", thermo2:");
  Serial.print(thermo2);

  // print out sht data
  Serial.print(", stemp1:");
  Serial.print(stemp1);
  Serial.print(", shumid1:");
  Serial.print(shumid1);
  Serial.print(", stemp2:");
  Serial.print(stemp2);
  Serial.print(", shumid2:");
  Serial.print(shumid2);
  Serial.print(", stemp3:");
  Serial.print(stemp3);
  Serial.print(", shumid3:");
  Serial.print(shumid3);
  //print flow data
  // Serial.print(", flowRate:");
  // Serial.print(flowRate);
  // Serial.print(", totalmL:");
  // Serial.print(totalmL);
  Serial.println();
}

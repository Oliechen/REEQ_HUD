//
//  ViewController.swift
//  REEQ_HUD
//
//  Created by ChengYen Chen on 05/11/2017.
//  Copyright © 2017 ChengYen Chen. All rights reserved.
//

import UIKit
import UICircularProgressRing
import CoreBluetooth
import HGCircularSlider

class ViewController: UIViewController, CBCentralManagerDelegate, CBPeripheralDelegate {

    @IBOutlet weak var testProgressRing: UICircularProgressRingView!
    
    @IBOutlet weak var powerProgressRing: UICircularProgressRingView!
    @IBOutlet weak var timeProgressRing: UICircularProgressRingView!
    @IBOutlet weak var countProgressRing: UICircularProgressRingView!
    
    @IBOutlet weak var btImageView: UIImageView!
    @IBOutlet weak var counterTimerLabel: UILabel!
    @IBOutlet weak var resistRangeLabel: UILabel!
    @IBOutlet weak var resistanceOutlet: CircularSlider!
    
    //MARK: BT communication - define the delegation
    var central: CBCentralManager!
    var peripheral: CBPeripheral!
    
    let BTMODULE_NAME = "HC-08"
    //let BTMODULE_NAME = "BikeBT"
    let BTMODULE_NAME_SERVICE_UUID = "FFE0"
    let BTMODULE_NAME_CHARACTERISTIC_UUID = "FFE1"
    
    var countDownTimer = Timer()
    var timerCount : Int = 600
    var dutyParameter : Int?
    var speedParameter : Int?
    var writeEnableToggle : Bool = false
    var initWriteDataCount : Int = 0
    var count : CGFloat = 0
    var resistanceDuty : Int = 1

    override func viewDidLoad() {
        super.viewDidLoad()
        central = CBCentralManager(delegate: self, queue: nil)
        
        
        countProgressRing.font = UIFont.systemFont(ofSize: 50)
        powerProgressRing.font = UIFont.systemFont(ofSize: 50)
        resistRangeLabel.font = UIFont.systemFont(ofSize: 50)
        timeProgressRing.font = UIFont.systemFont(ofSize: 35)
        
        //timeProgressRing.fontColor = UIColor.white
        timeProgressRing.shouldShowValueText = false
        countProgressRing.fontColor = UIColor.white
        powerProgressRing.fontColor = UIColor.white
        
        timeProgressRing.maxValue = 600
        countProgressRing.maxValue = 12
        powerProgressRing.maxValue = 500
        
        resistanceOutlet.endPointValue = 1
        resistanceOutlet.addTarget(self, action: #selector(updateTexts), for: .valueChanged)
        
        let countDownTimer = Timer.scheduledTimer(timeInterval: 1.0, target: self, selector: #selector(ViewController.updateCounter), userInfo: nil, repeats: true)
        
        btImageView.isHidden = true
    
        }
    
    //MARK: BT communication -
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if central.state == .poweredOn {
        central.scanForPeripherals(withServices: nil, options: nil)
        } else {
            let btMissingAlertController = UIAlertController(title: "藍牙未開啟", message: "請至設定開啟藍牙系統", preferredStyle: UIAlertControllerStyle.alert)
            
            btMissingAlertController.addAction(UIAlertAction(title: "OK", style: UIAlertActionStyle.default, handler: nil))
            
            present(btMissingAlertController, animated: true, completion: nil)
            
        }
    }
    
    //MARK: CentralManager search and discover all Peripheral
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        if let name = peripheral.name {
            print(name)
            if name.contains(BTMODULE_NAME) == true{
                self.central.stopScan()
                self.peripheral = peripheral
                self.peripheral.delegate = self
                central.connect(peripheral, options: nil)
                print("find BTMODULE_NAME")
            }
        }
    }
    
    //Receive the result of connecting due to "didConnect"
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        
        peripheral.delegate = self
        peripheral.discoverServices(nil)
        print("did connect Peripheral devices")
        btImageView.isHidden = false
    }
    
    //MARK: CBPeripheral Delegate
    //CBPeripheral Receive the result of discovering services.
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        
        for service in peripheral.services!{
            if service.uuid.uuidString == BTMODULE_NAME_SERVICE_UUID {
                peripheral.discoverCharacteristics(nil, for: service)
                print("\(service.uuid.uuidString)")
                //dataLogTextView.text! = "\(service.uuid.uuidString)"
            }
        }
    }
    
    //CBPeripheral Receive the result of discovering Characteristic
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        if error != nil{
            print("didDiscover Characteristic is facing ERROR issue")}
        else{
            for characteristic in service.characteristics! as [CBCharacteristic] {
                switch characteristic.uuid.uuidString {
                    
                case "FFE1":
                    //Set Notification
                    peripheral.setNotifyValue(true, for: characteristic)
                default:
                    print("get nil value")
                }
            }
        }
    }
    
    // Receive notifications for changes of a characteristic’s value
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        var rawArray : String = ""
        
        switch characteristic.uuid.uuidString {
        case "FFE1":
            
            //App read dataValue from bikeBT
            update(btControllerData: characteristic.value!)
            print("characteristic value is: \(characteristic.value!)")
            
            //App write dataValue to bikeBT
            if initWriteDataCount == 0 {
                rawArray = "460001000C0D"
                initWriteDataCount += 1
            }else if writeEnableToggle == true {
                rawArray = writeDataToBTModule()
                writeEnableToggle = false
            }
            
            let data = rawArray.data(using: String.Encoding.utf8)
            peripheral.writeValue(data as! Data, for: characteristic, type: CBCharacteristicWriteType.withoutResponse)
            
            //initial value: "460001000C0D"
        default:
            print("get nil value")
            
        }
    }
    
    func update(btControllerData:Data){
        print("--- UPDATING ..")
        
        var convertBtControllerData:[String] = []
        var convertBtControllerDataInt:[Int] = []
        //display single data
        for btControllerDataUnit in btControllerData {
            //test Int value
            convertBtControllerDataInt.append(Int(btControllerDataUnit))
            
            // Data Int convert to ACSII
            let TempBtDataUnit = UnicodeScalar(btControllerDataUnit)
            let charBtDataUnit = TempBtDataUnit.escaped(asASCII: true)
            convertBtControllerData.append((charBtDataUnit))
        }
        
        let startFlag1 = (convertBtControllerData[0]+convertBtControllerData[1]).hexStringToInt()
        let count2 = (convertBtControllerData[2]+convertBtControllerData[3]).hexStringToInt()
        let power3 = (convertBtControllerData[4]+convertBtControllerData[5]).hexStringToInt()
        let speedPulse4 = (convertBtControllerData[6]+convertBtControllerData[7]+convertBtControllerData[8]+convertBtControllerData[9]).hexStringToInt()
        let maxSpeedCode5 = (convertBtControllerData[10]+convertBtControllerData[11]).hexStringToInt()
        let checkSumCode6 = startFlag1 ^ count2 ^ power3 ^ maxSpeedCode5
        let errorCode7 = (convertBtControllerData[12]+convertBtControllerData[13]).hexStringToInt()
        
        count += 1
        
       // countProgressRing.setProgress(value: CGFloat(count), animationDuration: 1)
       // powerProgressRing.setProgress(value:CGFloat(speedPulse4/100), animationDuration: 1)
        timeProgressRing.setProgress(value: CGFloat(count), animationDuration: 1)
        countProgressRing.setProgress(value:CGFloat(count2), animationDuration: 1)
        powerProgressRing.setProgress(value:CGFloat(power3), animationDuration: 1)
        print("\(startFlag1), \(count2), \(power3), \(speedPulse4), \(maxSpeedCode5), \(checkSumCode6), \(errorCode7)")
        
    }
    
    //Mobile App Write Data to Controller
    func writeDataToBTModule() -> String {
        var DataToBtModule : String = ""
        let writeStartFlag = "46"
        let dutyFlag = "0"+String(resistanceDuty)
        let countFlag = "7D"
        let adjXorFlag = "00"
        let writeEndFlag = "0D"
        
       let tempCheckSumFlag = dutyFlag.hexStringToInt() ^ countFlag.hexStringToInt() ^ adjXorFlag.hexStringToInt() ^ writeEndFlag.hexStringToInt()
        let checkSumFlag = String(tempCheckSumFlag, radix:16)
        print("hc is " + checkSumFlag)
        DataToBtModule = writeStartFlag + dutyFlag + countFlag + adjXorFlag + checkSumFlag + writeEndFlag
        
        print("WrtingData is" + DataToBtModule)
        return DataToBtModule
    }
    
    @IBAction func resistantBtn(_ sender: Any) {
    
    
    }
    
    
    @IBAction func startBtn(_ sender: Any) {
        writeEnableToggle = true
        
    }
    
    
    @objc func updateTexts(){
        
    resistanceDuty = Int(resistanceOutlet.endPointValue / 10)
    print("\(resistanceOutlet.endPointValue), \(resistanceDuty)")
    resistRangeLabel.text = "\(resistanceDuty)"
        

    }
    
    @objc func updateCounter() {
        if timerCount > 0 {
            print("\(timerCount) seconds to the end of the world")
            let minutes = timerCount / 60
            let seconds = timerCount % 60
            
            let secondsString = seconds > 9 ? "\(seconds)" : "0\(seconds)"
            let minutesString = minutes > 9 ? "\(minutes)" : "0\(minutes)"
            
            counterTimerLabel.text = minutesString + ":" + secondsString
            timerCount -= 1
            print("\(countDownTimer)")
        }
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }


}

//MARK: ExtensionForHexToInt
extension String{
    func hexStringToInt() -> Int {
        let str = self.uppercased()
        var sum = 0
        for i in str.utf8 {
            sum = sum * 16 + Int(i) - 48 // 0-9 從48開始
            if i >= 65 {                 // A-Z 從65開始，但有初始值10，所以應該是減去55
                sum -= 7
            }
        }
        return sum
    }
}

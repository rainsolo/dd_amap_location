//
//  SwiftAMapLocationPlugin.swift
//  amap_location
//
//  Created by 李亚洲 on 2019/11/4.
//

import Foundation

import Flutter

import AMapLocationKit

public class SwiftAMapLocationPlugin: NSObject, FlutterPlugin, AMapLocationManagerDelegate {

    private var locationManager: AMapLocationManager?
    private var onceLocationManager: AMapLocationManager?
    //private var completionBlock: AMapLocatingCompletionBlock?
    private var channel: FlutterMethodChannel?
    
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "amap_location", binaryMessenger: registrar.messenger())
        let instance = SwiftAMapLocationPlugin()
        instance.channel = channel
        registrar.addMethodCallDelegate(instance, channel: channel)
    }
    
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        
        let mainAsyncResult: FlutterResult = { data in
            return DispatchQueue.main.async {
                result(data)
            }
        }
        
        switch call.method {
        case "startup":
        //启动系统
            startup(call.arguments as! [String: Any], mainAsyncResult)
        case "shutdown":
        //关闭系统
            shutdown(mainAsyncResult)
        case "getLocation":
        //进行单次定位请求
            getLocation(call.arguments as! [String: Any], mainAsyncResult)
        case "stopLocation":
        //停止监听位置改变
            stopLocation(mainAsyncResult)
        case "startLocation":
        //开始监听位置改变
            startLocation(mainAsyncResult)
        case "updateOption":
            updateOption(call.arguments as! [String : Any], mainAsyncResult)
        case "setApiKey":
            AMapServices.shared()?.enableHTTPS = true
            AMapServices.shared()?.apiKey = call.arguments as? String
            mainAsyncResult(true)
        default:
            mainAsyncResult(FlutterMethodNotImplemented)
        }
    }

    private func getDesiredAccuracy(_ str: String?) -> Double {
        if("kCLLocationAccuracyBest" == str) {
            return kCLLocationAccuracyBest
        }
            else if("kCLLocationAccuracyNearestTenMeters" == str){
            return kCLLocationAccuracyNearestTenMeters
        }
            else if("kCLLocationAccuracyHundredMeters" == str){
            return kCLLocationAccuracyHundredMeters
        }
        else if("kCLLocationAccuracyKilometer" == str){
            return kCLLocationAccuracyKilometer
        }
        else{
            return kCLLocationAccuracyThreeKilometers
        }
    }
    
    
    private func updateOption(_ args: Dictionary<String, Any>, _ result: @escaping FlutterResult) {
        
        guard let locationManager = self.locationManager else {
            result(false)
            return
        }
        
        updateOption(locationManager, args, result)
    }

    private func updateOption(_ locationManager: AMapLocationManager, _ args: Dictionary<String, Any>?, _ result: FlutterResult?) {
        
        guard let args = args else {
            result?(false)
            return
        }
         
            //设置期望定位精度
        if let desiredAccuracy = args["desiredAccuracy"] as? String {
            locationManager.desiredAccuracy = getDesiredAccuracy(desiredAccuracy)
        }
        
        if let pausesLocationUpdatesAutomatically = args["pausesLocationUpdatesAutomatically"] as? Bool {
            locationManager.pausesLocationUpdatesAutomatically = pausesLocationUpdatesAutomatically
        }
        
        if let distanceFilter = args["distanceFilter"] as? Double {
            locationManager.distanceFilter = distanceFilter
        }
            
        //设置在能不能再后台定位
        if let allowsBackgroundLocationUpdates = args["allowsBackgroundLocationUpdates"] as? Bool {
            locationManager.allowsBackgroundLocationUpdates =  allowsBackgroundLocationUpdates
        }
            
        //设置定位超时时间
        if let locationTimeout = args["locationTimeout"] as? Int {
            locationManager.locationTimeout = locationTimeout
        }
        
        //设置逆地理超时时间
        if let reGeocodeTimeout = args["reGeocodeTimeout"] as? Int {
            locationManager.reGeocodeTimeout = reGeocodeTimeout
        }
            
            //定位是否需要逆地理信息
        if let locatingWithReGeocode = args["locatingWithReGeocode"] as? Bool {
            locationManager.locatingWithReGeocode =  locatingWithReGeocode
        }
            
        ///检测是否存在虚拟定位风险，默认为NO，不检测。 \n注意:设置为YES时，单次定位通过 AMapLocatingCompletionBlock 的error给出虚拟定位风险提示；连续定位通过 amapLocationManager:didFailWithError: 方法的error给出虚拟定位风险提示。error格式为error.domain==AMapLocationErrorDomain; error.code==AMapLocationErrorRiskOfFakeLocation;
        if let detectRiskOfFakeLocation = args["detectRiskOfFakeLocation"] as? Bool {
            locationManager.detectRiskOfFakeLocation = detectRiskOfFakeLocation
        }
        result?(true)
    }

    private func startLocation(_ result: FlutterResult) {
        guard let locationManager = self.locationManager else {
            result(false)
            return
        }
        
        locationManager.startUpdatingLocation()
        result(true)
    }

    private func stopLocation(_ result: FlutterResult) {
        
        guard let locationManager = self.locationManager else {
            result(false)
            return
        }
        
        locationManager.stopUpdatingLocation()
        
        result(true)
    }

    private func getLocation(_ args: [String : Any], _ result: @escaping FlutterResult) {
        
        if (onceLocationManager == nil) {
            onceLocationManager = AMapLocationManager()
        }
        
        guard let locationManager = self.onceLocationManager else {
            result([
                     "code": "-1",
                     "description": "初始化失败",
                     "success": false,
                ])
            return
        }
    
        updateOption(locationManager, args, nil)
        
        let needsAddress = args["needsAddress"] as! Bool
        
        locationManager.requestLocation(withReGeocode: needsAddress, completionBlock: { (location, regeo, error) in
            if let location = location {
                var md: Dictionary<String, Any> = SwiftAMapLocationPlugin.location2map(location)
                
                if needsAddress {
                    if let regeo = regeo {
                        md.merge(SwiftAMapLocationPlugin.regeocode2map(regeo), uniquingKeysWith: { $1 })
                        md["code"] = 0
                        md["success"] = true
                    } else {
                        md["code"] = 0
                        md["success"] = true
                        md["description"] = "逆地理编码失败"
                    }
                }
                result(md)
            }
            else if let error = error as NSError? {
                if error.code == AMapLocationErrorCode.locateFailed.rawValue {
                    //定位错误：此时location和regeocode没有返回值，不进行annotation的添加
                    result([
                             "code":error.code,
                             "description":error.localizedDescription,
                             "success":false,
                        ]);
                    }
                else if (error.code == AMapLocationErrorCode.reGeocodeFailed.rawValue
                    || error.code == AMapLocationErrorCode.timeOut.rawValue
                    || error.code == AMapLocationErrorCode.cannotFindHost.rawValue
                    || error.code == AMapLocationErrorCode.badURL.rawValue
                    || error.code == AMapLocationErrorCode.notConnectedToInternet.rawValue
                    || error.code == AMapLocationErrorCode.cannotConnectToHost.rawValue)
                {
                    //逆地理错误：在带逆地理的单次定位中，逆地理过程可能发生错误，此时location有返回值，regeocode无返回值，进行annotation的添加
                    debugPrint("逆地理错误:{\(error.code) - \(error.localizedDescription)};");
                }
                else if (error.code == AMapLocationErrorCode.riskOfFakeLocation.rawValue)
                {
                    //存在虚拟定位的风险：此时location和regeocode没有返回值，不进行annotation的添加
                    debugPrint("存在虚拟定位的风险:{\(error.code) - \(error.localizedDescription)};")
                    result([
                             "code": error.code,
                             "description": error.localizedDescription,
                             "success": false,
                             ]);
                }
                else
                {
                    //没有错误：location有返回值，regeocode是否有返回值取决于是否进行逆地理操作，进行annotation的添加
                }
            }
        })
    }


//    private func checkNull(value: Any?) -> Any{
//        return value ?? NSNull()
//    }

    private static func regeocode2map(_ regeocode: AMapLocationReGeocode) -> Dictionary<String, Any> {
        let data: [String : Any?] = [
            "formattedAddress": regeocode.formattedAddress,
                 "country": regeocode.country,
                 "province": regeocode.province,
                 "city": regeocode.city,
                 "district": regeocode.district,
                 "citycode": regeocode.citycode,
                 "adcode": regeocode.adcode,
                 "street": regeocode.street,
                 "number": regeocode.number,
                 "POIName": regeocode.poiName,
                 "AOIName": regeocode.aoiName,
            ]
        
        return data.filter { (item) -> Bool in
            return item.value != nil
            } as Dictionary<String, Any>
    }

    private static func location2map(_ location: CLLocation) -> Dictionary<String, Double> {
        return [
            "latitude": location.coordinate.latitude,
             "longitude": location.coordinate.longitude,
             "accuracy": (location.horizontalAccuracy + location.verticalAccuracy) / 2,
             "altitude": location.altitude,
             "speed": location.speed,
             "timestamp": location.timestamp.timeIntervalSince1970
        ]
    }


    private func startup(_ args: Dictionary<String, Any>, _ result: @escaping FlutterResult) {
        
        if let _ = locationManager {
            result(false)
            return
        }
        
        locationManager = AMapLocationManager()
        locationManager?.delegate  = self
        
        updateOption(args, result)
    }


    private func shutdown(_ result: FlutterResult) {
        guard let locationManager = self.locationManager else {
            result(false)
            return
        }
        
        // 停止定位
        locationManager.stopUpdatingLocation()
        locationManager.delegate = nil
        
        self.locationManager = nil
        
        result(true)
    }
    /**
     *  @brief 连续定位回调函数.注意：如果实现了本方法，则定位信息不会通过amapLocationManager:didUpdateLocation:方法回调。
     *  @param manager 定位 AMapLocationManager 类。
     *  @param location 定位结果。
     *  @param reGeocode 逆地理信息。
     */
    public func amapLocationManager(_ manager: AMapLocationManager!, didUpdate location: CLLocation!, reGeocode: AMapLocationReGeocode!) {
        
        var md: [String : Any] = SwiftAMapLocationPlugin.location2map(location)
        if (reGeocode != nil) {
            md.merge(SwiftAMapLocationPlugin.regeocode2map(reGeocode), uniquingKeysWith: { $1})
        }
        md["success"] = true
        
        channel?.invokeMethod("updateLocation", arguments: md)
    }


    /**
     *  @brief 当定位发生错误时，会调用代理的此方法。
     *  @param manager 定位 AMapLocationManager 类。
     *  @param error 返回的错误，参考 CLError 。
     */
    public func amapLocationManager(_ manager: AMapLocationManager!, didFailWithError error: Error!) {
        let error = error as NSError
        let value: [String : Any?] = [
            "code": error.code,
            "description": error.localizedDescription,
            "success": false,
        ]
        self.channel?.invokeMethod("updateLocation", arguments: value)
    }
    
}


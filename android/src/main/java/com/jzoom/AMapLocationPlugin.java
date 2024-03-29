package com.jzoom.amaplocation;

import android.app.Activity;
import android.content.Context;
import android.util.Log;

import com.amap.api.location.AMapLocation;
import com.amap.api.location.AMapLocationClient;
import com.amap.api.location.AMapLocationClientOption;
import com.amap.api.location.AMapLocationListener;

import java.util.HashMap;
import java.util.Map;

import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.MethodChannel.MethodCallHandler;
import io.flutter.plugin.common.MethodChannel.Result;
import io.flutter.plugin.common.PluginRegistry.Registrar;

/**
 * FlutterAmapLocationPlugin
 */
public class AMapLocationPlugin implements MethodCallHandler {


    private Registrar registrar;
    private MethodChannel channel;
    private AMapLocationClientOption option;
    private AMapLocationClient onceLocationClient;
    private AMapLocationClient multiLocationClient;

    public AMapLocationPlugin(Registrar registrar, MethodChannel channel) {
        this.registrar = registrar;
        this.channel = channel;
    }

    private Activity getActivity() {
        return registrar.activity();
    }

    private Context getApplicationContext() {
        return registrar.activity().getApplicationContext();
    }

    /**
     * Plugin registration.
     */
    public static void registerWith(Registrar registrar) {
        final MethodChannel channel = new MethodChannel(registrar.messenger(), "amap_location");
        channel.setMethodCallHandler(new AMapLocationPlugin(registrar, channel));
    }

    @Override
    public void onMethodCall(MethodCall call, Result result) {
        String method = call.method;

        //显然下面的任何方法都应该放在同步块处理

        if ("startup".equals(method)) {
            //启动
            result.success(this.startup((Map) call.arguments));

        } else if ("shutdown".equals(method)) {
            //关闭
            result.success(this.shutdown());

        } else if ("getLocation".equals(method)) {
            this.getLocation((Map) call.arguments, result);

        } else if ("startLocation".equals(method)) {
            //启动定位,如果还没有启动，那么返回false
            result.success(this.startLocation());

        } else if ("stopLocation".equals(method)) {
            //停止定位
            result.success(this.stopLocation());

        } else if ("updateOption".equals(method)) {
            result.success(this.updateOption((Map) call.arguments));

        } else if ("setApiKey".equals(method)) {
            result.success(false);

        } else {
            result.notImplemented();
        }
    }

    /**
     * 单次定位
     */
    private void getLocation(Map params, final Result result) {
        synchronized (this) {
            if (onceLocationClient == null) {
                onceLocationClient = new AMapLocationClient(getApplicationContext());
            }
            AMapLocationClientOption onceOption = new AMapLocationClientOption();
            parseOptions(onceOption, params);
            onceOption.setOnceLocation(true);
            onceLocationClient.setLocationOption(onceOption);
            onceLocationClient.setLocationListener(new AMapLocationListener() {
                @Override
                public void onLocationChanged(AMapLocation aMapLocation) {
                    result.success(resultToMap(aMapLocation));
                }
            });
            onceLocationClient.startLocation();
        }// 在单次定位情况下，定位无论成功与否，都无需调用stopLocation()方法移除请求，定位sdk内部会移除
    }

    private static final String TAG = "AmapLocationPugin";

    private Map resultToMap(AMapLocation a) {

        Map<String, Object> map = new HashMap<>();

        if (a != null) {

            if (a.getErrorCode() != 0) {
                //错误信息

                map.put("description", a.getErrorInfo());
                map.put("success", false);

            } else {
                map.put("success", true);


                map.put("accuracy", a.getAccuracy());
                map.put("altitude", a.getAltitude());
                map.put("speed", a.getSpeed());
                map.put("timestamp", (double) a.getTime() / 1000);
                map.put("latitude", a.getLatitude());
                map.put("longitude", a.getLongitude());
                map.put("locationType", a.getLocationType());
                map.put("provider", a.getProvider());


                map.put("formattedAddress", a.getAddress());
                map.put("country", a.getCountry());
                map.put("province", a.getProvince());
                map.put("city", a.getCity());
                map.put("district", a.getDistrict());
                map.put("citycode", a.getCityCode());
                map.put("adcode", a.getAdCode());
                map.put("street", a.getStreet());
                map.put("number", a.getStreetNum());
                map.put("POIName", a.getPoiName());
                map.put("AOIName", a.getAoiName());

            }

            map.put("code", a.getErrorCode());

            Log.d(TAG, "定位获取结果:" + a.getLatitude() + " code：" + a.getErrorCode() + " 省:" + a.getProvince());


        }

        return map;
    }

    private boolean stopLocation() {
        synchronized (this) {
            if (multiLocationClient == null) {
                return false;
            }
            multiLocationClient.stopLocation();
            return true;
        }

    }

    private boolean shutdown() {
        synchronized (this) {
            if (multiLocationClient != null) {
                multiLocationClient.stopLocation();
                multiLocationClient.onDestroy();
                multiLocationClient = null;
                option = null;
                return true;
            }
            return false;
        }


    }

    private boolean startLocation() {
        synchronized (this) {
            if (multiLocationClient == null) {
                multiLocationClient = new AMapLocationClient(getApplicationContext());
            }
            multiLocationClient.setLocationOption(option);
            multiLocationClient.setLocationListener(new AMapLocationListener() {
                @Override
                public void onLocationChanged(AMapLocation aMapLocation) {
                    if (channel != null)
                        channel.invokeMethod("updateLocation", resultToMap(aMapLocation));
                }
            });
            multiLocationClient.startLocation();
            return true;
        }

    }

    private boolean startup(Map arguments) {
        synchronized (this) {
            option = new AMapLocationClientOption();
            parseOptions(option, arguments);
            return true;
        }
    }

    private boolean updateOption(Map arguments) {
        synchronized (this) {
            parseOptions(option, arguments);
            return true;
        }
    }

    /**
     * this.locationMode : AMapLocationMode.Hight_Accuracy,
     * this.gpsFirst:false,
     * this.httpTimeOut:10000,             //30有点长，特殊情况才需要这么长，改成10
     * this.interval:2000,
     * this.needsAddress : true,
     * this.onceLocation : false,
     * this.onceLocationLatest : false,
     * this.locationProtocol : AMapLocationProtocol.HTTP,
     * this.sensorEnable : false,
     * this.wifiScan : true,
     * this.locationCacheEnable : true,
     * <p>
     * this.allowsBackgroundLocationUpdates : false,
     * this.desiredAccuracy : CLLocationAccuracy.kCLLocationAccuracyBest,
     * this.locatingWithReGeocode : false,
     * this.locationTimeout : 10000,     //30有点长，特殊情况才需要这么长，改成10
     * this.pausesLocationUpdatesAutomatically : false,
     * this.reGeocodeTimeout : 5000,
     * <p>
     * <p>
     * this.geoLanguage : GeoLanguage.DEFAULT,
     */
    private void parseOptions(AMapLocationClientOption option, Map arguments) {
        //  AMapLocationClientOption option = new AMapLocationClientOption();
        option.setLocationMode(AMapLocationClientOption.AMapLocationMode.valueOf((String) arguments.get("locationMode")));//可选，设置定位模式，可选的模式有高精度、仅设备、仅网络。默认为高精度模式
        option.setGpsFirst((Boolean) getOrDefault(arguments, "gpsFirst", false));//可选，设置是否gps优先，只在高精度模式下有效。默认关闭
        option.setHttpTimeOut((Integer) getOrDefault(arguments, "httpTimeOut", 30));//可选，设置网络请求超时时间。默认为30秒。在仅设备模式下无效
        option.setInterval((Integer) getOrDefault(arguments, "interval", 2));//可选，设置定位间隔。默认为2秒
        option.setNeedAddress((Boolean) getOrDefault(arguments, "needsAddress", true));//可选，设置是否返回逆地理地址信息。默认是true
        option.setOnceLocation((Boolean) getOrDefault(arguments, "onceLocation", false));//可选，设置是否单次定位。默认是false
        option.setOnceLocationLatest((Boolean) getOrDefault(arguments, "onceLocationLatest", false));//可选，设置是否等待wifi刷新，默认为false.如果设置为true,会自动变为单次定位，持续定位时不要使用
        AMapLocationClientOption.setLocationProtocol(AMapLocationClientOption.AMapLocationProtocol.valueOf((String) arguments.get("locationProtocol")));//可选， 设置网络请求的协议。可选HTTP或者HTTPS。默认为HTTP
        option.setSensorEnable((Boolean) getOrDefault(arguments, "sensorEnable", false));//可选，设置是否使用传感器。默认是false
        option.setWifiScan((Boolean) getOrDefault(arguments, "wifiScan", true)); //可选，设置是否开启wifi扫描。默认为true，如果设置为false会同时停止主动刷新，停止以后完全依赖于系统刷新，定位位置可能存在误差
        option.setLocationCacheEnable((Boolean) getOrDefault(arguments, "locationCacheEnable", true)); //可选，设置是否使用缓存定位，默认为true
        option.setGeoLanguage(AMapLocationClientOption.GeoLanguage.valueOf((String) arguments.get("geoLanguage")));//可选，设置逆地理信息的语言，默认值为默认语言（根据所在地区选择语言）
    }

    private Object getOrDefault(Map map, Object key, Object defaultValue) {
        Object value = map.get(key);
        if (value == null)
            value = defaultValue;
        return value;
    }
}

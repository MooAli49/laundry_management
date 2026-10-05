package com.example.bluetooth_print_plus.bluetooth_print_plus;

import static android.bluetooth.BluetoothDevice.DEVICE_TYPE_LE;

import static androidx.core.app.ActivityCompat.startActivityForResult;

import android.Manifest;
import android.app.Activity;
import android.app.Application;
import android.bluetooth.BluetoothAdapter;
import android.bluetooth.BluetoothDevice;
import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.content.IntentFilter;
import android.content.pm.PackageManager;
import android.os.Build;
import android.os.Handler;
import android.os.Looper;
import android.util.Log;

import androidx.annotation.RequiresApi;

import com.example.bluetooth_print_plus.bluetooth_print_plus.payload.BPPState;
import com.example.bluetooth_print_plus.bluetooth_print_plus.payload.BluetoothParameter;
import com.example.bluetooth_print_plus.bluetooth_print_plus.payload.Printer;
import com.example.bluetooth_print_plus.bluetooth_print_plus.payload.ThreadPoolManager;
import com.gprinter.bean.PrinterDevices;
import com.gprinter.io.PortManager;
import com.gprinter.utils.CallbackListener;
import com.gprinter.utils.Command;
import com.gprinter.utils.LogUtils;
import com.gprinter.utils.ConnMethod;
import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.embedding.engine.plugins.activity.ActivityAware;
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding;
import io.flutter.plugin.common.*;
import io.flutter.plugin.common.EventChannel.EventSink;
import io.flutter.plugin.common.EventChannel.StreamHandler;
import io.flutter.plugin.common.MethodChannel.MethodCallHandler;
import io.flutter.plugin.common.MethodChannel.Result;
import io.flutter.plugin.common.PluginRegistry.RequestPermissionsResultListener;
import pub.devrel.easypermissions.EasyPermissions;

import java.io.IOException;
import java.util.HashMap;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.Objects;

/**
 * BluetoothPrintPlusPlugin
 *
 * @author amoLink
 */
public class BluetoothPrintPlusPlugin
        implements FlutterPlugin, ActivityAware, MethodCallHandler, RequestPermissionsResultListener {
  private static final String TAG = "BluetoothPrintPlusPlugin";
  private static final int REQUEST_LOCATION_PERMISSIONS = 1452;
  private final Object initializationLock = new Object();
  private Context context;
  private Activity activity;
  private Result pendingResult;
  public PortManager portManager = null;
  private BluetoothAdapter mBluetoothAdapter;

  private FlutterPluginBinding pluginBinding;
  private ActivityPluginBinding activityBinding;
  private MethodChannel channel;
  private EventSink sink;
  private MethodChannel tscChannel;
  private MethodChannel cpclChannel;
  private MethodChannel escChannel;
  private EventChannel stateChannel;
  private final Object connectionLock = new Object();
  private int connectionGeneration = 0;
  private int activeConnectionGeneration = 0;
  private final List<Map<String, Object>> pendingConnectionEvents = new ArrayList<>();
  private final TscCommandPlugin tscCommandPlugin = new TscCommandPlugin();
  private final CpclCommandPlugin cpclCommandPlugin = new CpclCommandPlugin();
  private final EscCommandPlugin escCommandPlugin = new EscCommandPlugin();

  public BluetoothPrintPlusPlugin() {}

  @Override
  public void onAttachedToEngine(FlutterPluginBinding binding) {
    pluginBinding = binding;
  }

  @Override
  public void onDetachedFromEngine(FlutterPluginBinding binding) {
    pluginBinding = null;
  }

  @Override
  public void onAttachedToActivity(ActivityPluginBinding binding) {
    activityBinding = binding;
    setup(
            pluginBinding.getBinaryMessenger(),
            (Application) pluginBinding.getApplicationContext(),
            activityBinding.getActivity(),
            activityBinding
    );
  }

  @Override
  public void onDetachedFromActivity() {
    tearDown();
  }

  @Override
  public void onDetachedFromActivityForConfigChanges() {
    onDetachedFromActivity();
  }

  @Override
  public void onReattachedToActivityForConfigChanges(ActivityPluginBinding binding) {
    onAttachedToActivity(binding);
  }

  private void setup(
          final BinaryMessenger messenger,
          final Application application,
          final Activity activity,
          final ActivityPluginBinding activityBinding
  ) {
    synchronized (initializationLock) {
      LogUtils.i(TAG, "setup");
      this.activity = activity;
      this.context = application;
      channel = new MethodChannel(messenger, "bluetooth_print_plus/methods");
      channel.setMethodCallHandler(this);
      // tsc Channel
      tscChannel = new MethodChannel(messenger, "bluetooth_print_plus_tsc");
      tscCommandPlugin.setUpChannel(tscChannel);
      // cpcl Channel
      cpclChannel = new MethodChannel(messenger, "bluetooth_print_plus_cpcl");
      cpclCommandPlugin.setUpChannel(cpclChannel);
      // esc Channel
      escChannel = new MethodChannel(messenger, "bluetooth_print_plus_esc");
      escCommandPlugin.setUpChannel(escChannel);
      // state Channel
      stateChannel = new EventChannel(messenger, "bluetooth_print_plus/state");
      stateChannel.setStreamHandler(stateHandler);
      mBluetoothAdapter = BluetoothAdapter.getDefaultAdapter();

      activityBinding.addRequestPermissionsResultListener(this);
      initBroadcast();
    }
  }

  private void tearDown() {
    LogUtils.i(TAG, "teardown");
    if (context != null) {
      try {
        context.unregisterReceiver(mFindBlueToothReceiver);
      } catch (IllegalArgumentException ignored) {
        // The receiver may already be unregistered during activity teardown.
      }
    }
    sink = null;
    invalidateConnection();
    Printer.close();
    context = null;
    if (activityBinding != null) {
      activityBinding.removeRequestPermissionsResultListener(this);
    }
    activityBinding = null;
    if (channel != null) {
      channel.setMethodCallHandler(null);
    }
    channel = null;
    if (stateChannel != null) {
      stateChannel.setStreamHandler(null);
    }
    stateChannel = null;
    mBluetoothAdapter = null;
  }

  private void emitState(int state) {
    emitState(state, null, null);
  }

  private void emitState(int state, Integer generation) {
    emitState(state, generation, null);
  }

  private void emitState(int state, Integer generation, Integer connectionAttempt) {
    Map<String, Object> event = new HashMap<>();
    event.put("state", state);
    event.put("generation", generation);
    event.put("connectionAttempt", connectionAttempt);
    LogUtils.d(TAG, "[NATIVE] emitState payload=" + event + " sinkExists=" + (sink != null));
    new Handler(Looper.getMainLooper()).post(() -> {
      synchronized (connectionLock) {
        if (sink != null) {
          if (generation == null || state <= BPPState.BlueOn.getValue()) {
            LogUtils.d(TAG, "[NATIVE] sink.success completed payload=" + state);
            sink.success(state);
          } else {
            sink.success(event);
            LogUtils.d(TAG, "[NATIVE] sink.success completed payload=" + event);
          }
        } else if (generation != null) {
          pendingConnectionEvents.add(event);
          LogUtils.d(TAG, "[NATIVE] EventSink unavailable; buffered connection event count="
                  + pendingConnectionEvents.size());
        } else {
          LogUtils.d(TAG, "[NATIVE] EventSink unavailable; dropped non-connection event");
        }
      }
    });
  }

  private void invokeMethodIfAttached(String method, Object arguments) {
    if (channel != null) {
      channel.invokeMethod(method, arguments);
    }
  }

  @Override
  public void onMethodCall(MethodCall call, Result result) {
    if (mBluetoothAdapter == null && !"isAvailable".equals(call.method)) {
      result.error("bluetooth_unavailable", "the device does not have bluetooth", null);
      return;
    }
    switch (call.method) {
      case "state":
        state(result);
        break;
      case "startScan":
        startScan(result);
        break;
      case "stopScan":
        stopScan();
        result.success(null);
        break;
      case "connect":
        Map<String, Object> args = call.arguments();
        assert args != null;
        final String address = (String) args.get("address");
        final int connectionAttempt = ((Number) args.get("connectionAttempt")).intValue();
        stopScan();
        result.success(connect(address, connectionAttempt));
        break;
      case "disconnect":
        invalidateConnection();
        Printer.close();
        result.success(null);
        break;
      case "write":
        byte[] bytes = call.argument("data");
        try {
          LogUtils.d(TAG, "PRINT WRITE START bytes=" + (bytes == null ? 0 : bytes.length)
                  + " port=" + (Printer.getPortManager() == null ? "null" : Printer.getPortManager().getConnectStatus()));
          result.success(write(bytes));
        } catch (IOException e) {
          Log.e(TAG, "PRINT WRITE FAILURE exception=" + e.getMessage(), e);
          result.error("printer_write_failed", e.getMessage(), e.toString());
        }
        break;
      default:
        result.notImplemented();
        break;
    }
  }

  private void initBroadcast() {
    try {
      IntentFilter filter = new IntentFilter();
      filter.addAction(BluetoothDevice.ACTION_FOUND);
      filter.addAction(BluetoothAdapter.ACTION_DISCOVERY_FINISHED);
      context.registerReceiver(mFindBlueToothReceiver, filter);
    } catch (Exception ignored) {

    }
  }

  private final BroadcastReceiver mFindBlueToothReceiver = new BroadcastReceiver() {
    @Override
    public void onReceive(Context context, Intent intent) {
      String action = intent.getAction();
      if (BluetoothDevice.ACTION_FOUND.equals(action)) {
        BluetoothDevice device = intent.getParcelableExtra(BluetoothDevice.EXTRA_DEVICE);
        if (device == null || device.getName() == null) return;
        if (device.getType() == DEVICE_TYPE_LE) return;
        BluetoothParameter parameter = new BluetoothParameter();
        int rssi = Objects.requireNonNull(intent.getExtras()).getShort(BluetoothDevice.EXTRA_RSSI);
        parameter.setBluetoothName(device.getName());
        parameter.setBluetoothMac(device.getAddress());
        parameter.setBluetoothStrength(rssi + "");
        LogUtils.i(TAG, "\nBlueToothName: " + device.getName() + "\nMacAddress: " + device.getAddress() + "\nrssi: " + rssi);
        invokeMethodUIThread(device);
      }
    }
  };

  private void state(Result result) {
    try {
      switch (mBluetoothAdapter.getState()) {
        case BluetoothAdapter.STATE_OFF:
          result.success(BPPState.BlueOff.getValue());
          break;
        case BluetoothAdapter.STATE_ON:
          result.success(BPPState.BlueOn.getValue());
          break;
        default:
          break;
      }
    } catch (SecurityException e) {
      result.error("invalid_argument", "argument 'address' not found", null);
    }
  }

  private void startScan(Result result) {
    LogUtils.i(TAG, "start scan...");
    try {
      String[] perms = {
          Manifest.permission.BLUETOOTH,
          Manifest.permission.BLUETOOTH_ADMIN,
          Manifest.permission.BLUETOOTH_CONNECT,
          Manifest.permission.BLUETOOTH_SCAN,
          Manifest.permission.ACCESS_FINE_LOCATION,
      };
      if (EasyPermissions.hasPermissions(this.context, perms)) {
        // Already have permission, do the thing
        startScan();
      } else {
        // Do not have permissions, request them now
        EasyPermissions.requestPermissions(
                this.activity,
                "Bluetooth requires location permission!!!",
                REQUEST_LOCATION_PERMISSIONS,
                perms);
      }
      result.success(null);
    } catch (Exception e) {
      result.error("startScan", e.getMessage(), e);
    }
  }

  private void invokeMethodUIThread(BluetoothDevice device) {
    final Map<String, Object> ret = new HashMap<>();
    ret.put("address", device.getAddress());
    ret.put("name", device.getName());
    ret.put("type", device.getType());
    new Handler(Looper.getMainLooper()).post(() -> {
      if (!ret.isEmpty()) {
        invokeMethodIfAttached("ScanResult", ret);
      } else {
        LogUtils.w(TAG, "invokeMethodUIThread: tried to call method on closed channel: " + "ScanResult");
      }
    });
  }

  private void startScan() throws IllegalStateException {
    mBluetoothAdapter.startDiscovery();
  }

  private void stopScan() {
    mBluetoothAdapter.cancelDiscovery();
  }

  private int connect(final String mac, final int requestedGeneration) {
    final int generation;
    synchronized (connectionLock) {
      generation = requestedGeneration > 0 ? requestedGeneration : ++connectionGeneration;
      connectionGeneration = Math.max(connectionGeneration, generation);
      activeConnectionGeneration = generation;
    }
    LogUtils.d(TAG, "connectionAttempt=" + generation + " nativeGeneration=" + generation + " state=connect-start");
    ThreadPoolManager.getInstance().addTask(new Runnable() {
      @Override
      public void run() {
        if (portManager != null) {
          portManager.closePort();
          try {
            Thread.sleep(500);
          } catch (InterruptedException e) {
            throw new RuntimeException(e);
          }
        }
        if (mac != null) {
          PrinterDevices blueTooth = new PrinterDevices.Build()
                  .setContext(context)
                  .setConnMethod(ConnMethod.BLUETOOTH)
                  .setMacAddress(mac)
                  .setCommand(Command.ESC)
                  .setCallbackListener(new CallbackListener() {
                    @Override
                    public void onConnecting() { }

                    @Override
                    public void onCheckCommand() { }

                    @Override
                    public void onSuccess(PrinterDevices printerDevices) {
                      final String deviceName = (printerDevices != null && printerDevices.getBlueName() != null)
                              ? printerDevices.getBlueName()
                              : "unknown";
                      if (isCurrentConnection(generation)) {
                        LogUtils.d(TAG, "connectionAttempt=" + generation + " nativeGeneration=" + generation
                                + " callback=onSuccess state=connected device=" + deviceName);
                        emitState(BPPState.DeviceConnected.getValue(), generation, generation);
                      } else {
                        LogUtils.d(TAG, "IGNORING STALE CALLBACK connectionGeneration=" + generation
                                + " currentGeneration=" + getActiveConnectionGeneration()
                                + " callback=onSuccess device=" + deviceName);
                      }
                    }

                    @Override
                    public void onReceive(byte[] data) {
                      if (data == null) return;
                      // LogUtils.d(TAG, "Received Data: " + Arrays.toString(data));
                      new Handler(Looper.getMainLooper()).post(() -> {
                        invokeMethodIfAttached("ReceivedData", data);
                      });
                    }

                    @Override
                    public void onFailure() {
                      if (isCurrentConnection(generation)) {
                        LogUtils.d(TAG, "connectionAttempt=" + generation + " nativeGeneration=" + generation + " callback=onFailure");
                        invalidateConnectionIfCurrent(generation);
                        Printer.close();
                        emitState(BPPState.DeviceDisconnected.getValue(), generation, generation);
                      } else {
                        LogUtils.d(TAG, "IGNORING STALE CALLBACK connectionGeneration=" + generation
                                + " currentGeneration=" + getActiveConnectionGeneration()
                                + " callback=onFailure");
                      }
                    }

                    @Override
                    public void onDisconnect() {
                      if (isCurrentConnection(generation)) {
                        LogUtils.d(TAG, "connectionAttempt=" + generation + " nativeGeneration=" + generation + " callback=onDisconnect state=disconnected");
                        invalidateConnectionIfCurrent(generation);
                        emitState(BPPState.DeviceDisconnected.getValue(), generation, generation);
                      } else {
                        LogUtils.d(TAG, "IGNORING STALE CALLBACK connectionGeneration=" + generation
                                + " currentGeneration=" + getActiveConnectionGeneration()
                                + " callback=onDisconnect");
                      }
                    }
                  })
                  .build();
          Printer.connect(blueTooth);
        }
      }
    });
    return generation;
  }

  private boolean isCurrentConnection(int generation) {
    synchronized (connectionLock) {
      return activeConnectionGeneration == generation;
    }
  }

  private int getActiveConnectionGeneration() {
    synchronized (connectionLock) {
      return activeConnectionGeneration;
    }
  }

  private void invalidateConnection() {
    synchronized (connectionLock) {
      activeConnectionGeneration = 0;
    }
  }

  private void invalidateConnectionIfCurrent(int generation) {
    synchronized (connectionLock) {
      if (activeConnectionGeneration == generation) {
        activeConnectionGeneration = 0;
      }
    }
  }

  @SuppressWarnings("unchecked")
  private boolean write(byte[] data) throws IOException {
    if (data == null || data.length == 0) {
      throw new IOException("Printer write received empty data");
    }
    if (Printer.getPortManager() == null) {
      throw new IOException("Printer port is null");
    }
    LogUtils.d(TAG, "PRINT WRITE bytes=" + data.length + " portState="
            + Printer.getPortManager().getConnectStatus());
    boolean result = Printer.getPortManager().writeDataImmediately(data);
    LogUtils.d(TAG, result ? "PRINT WRITE SUCCESS" : "PRINT WRITE FAILURE returned=false");
    if (!result) {
      throw new IOException("Native printer port write returned false");
    }
    return result;
  }

  @Override
  public boolean onRequestPermissionsResult(int requestCode, String[] permissions, int[] grantResults) {
    LogUtils.d(TAG, "onRequestPermissionsResult");
    if (requestCode == REQUEST_LOCATION_PERMISSIONS) {
      if (grantResults[0] == PackageManager.PERMISSION_GRANTED) {
        startScan();
      } else {
        pendingResult.error("no_permissions", "this plugin requires location permissions for scanning", null);
        pendingResult = null;
      }
      return true;
    }
    return false;
  }

  private final StreamHandler stateHandler = new StreamHandler() {
    // private EventSink sink;
    private final BroadcastReceiver mReceiver = new BroadcastReceiver() {
      @Override
      public void onReceive(Context context, Intent intent) {
        final String action = intent.getAction();
        // LogUtils.d(TAG, "stateStreamHandler, current action: " + action);
        if (BluetoothAdapter.ACTION_STATE_CHANGED.equals(action)) {
          int blueState = intent.getIntExtra(BluetoothAdapter.EXTRA_STATE, 0);
          switch (blueState) {
            case BluetoothAdapter.STATE_ON:
              emitState(BPPState.BlueOn.getValue());
              break;
            case BluetoothAdapter.STATE_OFF:
              emitState(BPPState.BlueOff.getValue());
              break;
          }
        }
      }
    };

    @Override
    public void onListen(Object o, EventSink eventSink) {
      List<Map<String, Object>> pendingEvents;
      synchronized (connectionLock) {
        sink = eventSink;
        pendingEvents = new ArrayList<>(pendingConnectionEvents);
        pendingConnectionEvents.clear();
      }
      LogUtils.d(TAG, "[NATIVE] EventChannel onListen sinkExists=" + (sink != null)
              + " bufferedEvents=" + pendingEvents.size());
      for (Map<String, Object> pendingEvent : pendingEvents) {
        if (sink != null) {
          sink.success(pendingEvent);
          LogUtils.d(TAG, "[NATIVE] flushed buffered event=" + pendingEvent);
        }
      }
      if (context != null) {
        IntentFilter filter = new IntentFilter(BluetoothAdapter.ACTION_STATE_CHANGED);
        context.registerReceiver(mReceiver, filter);
      }
    }

    @Override
    public void onCancel(Object o) {
      LogUtils.d(TAG, "[NATIVE] EventChannel onCancel");
      sink = null;
      if (context != null) {
        try {
          context.unregisterReceiver(mReceiver);
        } catch (IllegalArgumentException ignored) {
          // The receiver may already be unregistered during activity teardown.
        }
      }
    }
  };
}

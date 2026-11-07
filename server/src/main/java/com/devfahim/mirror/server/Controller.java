package com.devfahim.mirror.server;

import android.os.SystemClock;
import android.view.InputDevice;
import android.view.InputEvent;
import android.view.KeyCharacterMap;
import android.view.KeyEvent;
import android.view.MotionEvent;

import java.io.DataInputStream;
import java.io.IOException;
import java.lang.reflect.Method;

/**
 * Mirror — Open-source Android screen mirroring and remote control
 * Author: Dev Fahim (devfahimbd)
 *
 * Controls input event injection (touch, mouse, keyboard, navigation) via Android InputManager.
 */
public final class Controller {
    // Control Packet Types
    public static final byte TYPE_INJECT_TOUCH = 1;
    public static final byte TYPE_INJECT_KEY = 2;
    public static final byte TYPE_INJECT_TEXT = 3;
    public static final byte TYPE_INJECT_SCROLL = 4;
    public static final byte TYPE_COMMAND = 5;

    // Commands
    public static final byte CMD_BACK = 1;
    public static final byte CMD_HOME = 2;
    public static final byte CMD_RECENTS = 3;
    public static final byte CMD_POWER = 4;
    public static final byte CMD_VOLUME_UP = 5;
    public static final byte CMD_VOLUME_DOWN = 6;
    public static final byte CMD_SCREEN_OFF = 7;
    public static final byte CMD_SCREEN_ON = 8;

    private static final int INJECT_INPUT_EVENT_MODE_ASYNC = 0;

    private final Method injectInputEventMethod;
    private final Object inputManager;
    private long lastDownTime = 0;

    public Controller() throws Exception {
        Class<?> imClass = Class.forName("android.hardware.input.InputManager");
        Method getInstance = imClass.getMethod("getInstance");
        this.inputManager = getInstance.invoke(null);
        this.injectInputEventMethod = imClass.getMethod("injectInputEvent", InputEvent.class, int.class);
    }

    public void handleControlStream(DataInputStream in, Device device) throws IOException {
        while (true) {
            byte type = in.readByte();
            switch (type) {
                case TYPE_INJECT_TOUCH:
                    handleTouchEvent(in, device);
                    break;
                case TYPE_INJECT_KEY:
                    handleKeyEvent(in);
                    break;
                case TYPE_INJECT_TEXT:
                    handleTextEvent(in);
                    break;
                case TYPE_INJECT_SCROLL:
                    handleScrollEvent(in, device);
                    break;
                case TYPE_COMMAND:
                    handleCommand(in);
                    break;
                default:
                    Ln.w("Unknown control packet type: " + type);
                    break;
            }
        }
    }

    private void handleTouchEvent(DataInputStream in, Device device) throws IOException {
        byte action = in.readByte(); // 0: DOWN, 1: UP, 2: MOVE
        float normX = in.readFloat(); // 0.0 to 1.0
        float normY = in.readFloat(); // 0.0 to 1.0

        int screenWidth = device.getScreenSize().x;
        int screenHeight = device.getScreenSize().y;

        float x = Math.max(0, Math.min(normX * screenWidth, screenWidth - 1));
        float y = Math.max(0, Math.min(normY * screenHeight, screenHeight - 1));

        long now = SystemClock.uptimeMillis();
        int motionAction;

        if (action == 0) {
            motionAction = MotionEvent.ACTION_DOWN;
            lastDownTime = now;
        } else if (action == 1) {
            motionAction = MotionEvent.ACTION_UP;
        } else {
            motionAction = MotionEvent.ACTION_MOVE;
        }

        MotionEvent event = MotionEvent.obtain(lastDownTime, now, motionAction, x, y, 1.0f, 1.0f, 0, 1.0f, 1.0f, 0, 0);
        event.setSource(InputDevice.SOURCE_TOUCHSCREEN);
        injectEvent(event);
        event.recycle();
    }

    private void handleKeyEvent(DataInputStream in) throws IOException {
        byte action = in.readByte(); // 0: DOWN, 1: UP
        int keyCode = in.readInt();
        int metaState = in.readInt();

        long now = SystemClock.uptimeMillis();
        int keyAction = (action == 0) ? KeyEvent.ACTION_DOWN : KeyEvent.ACTION_UP;

        KeyEvent event = new KeyEvent(now, now, keyAction, keyCode, 0, metaState,
                KeyCharacterMap.VIRTUAL_KEYBOARD, 0, 0, InputDevice.SOURCE_KEYBOARD);
        injectEvent(event);
    }

    private void handleTextEvent(DataInputStream in) throws IOException {
        int length = in.readInt();
        byte[] bytes = new byte[length];
        in.readFully(bytes);
        String text = new String(bytes, "UTF-8");

        KeyCharacterMap kcm = KeyCharacterMap.load(KeyCharacterMap.VIRTUAL_KEYBOARD);
        KeyEvent[] events = kcm.getEvents(text.toCharArray());
        if (events != null) {
            for (KeyEvent event : events) {
                injectEvent(event);
            }
        }
    }

    private void handleScrollEvent(DataInputStream in, Device device) throws IOException {
        float normX = in.readFloat();
        float normY = in.readFloat();
        float hScroll = in.readFloat();
        float vScroll = in.readFloat();

        int screenWidth = device.getScreenSize().x;
        int screenHeight = device.getScreenSize().y;
        float x = normX * screenWidth;
        float y = normY * screenHeight;

        long now = SystemClock.uptimeMillis();
        MotionEvent.PointerProperties[] pp = new MotionEvent.PointerProperties[1];
        pp[0] = new MotionEvent.PointerProperties();
        pp[0].id = 0;
        pp[0].toolType = MotionEvent.TOOL_TYPE_MOUSE;

        MotionEvent.PointerCoords[] pc = new MotionEvent.PointerCoords[1];
        pc[0] = new MotionEvent.PointerCoords();
        pc[0].x = x;
        pc[0].y = y;
        pc[0].setAxisValue(MotionEvent.AXIS_HSCROLL, hScroll);
        pc[0].setAxisValue(MotionEvent.AXIS_VSCROLL, vScroll);

        try {
            MotionEvent event = MotionEvent.obtain(now, now, MotionEvent.ACTION_SCROLL, 1, pp, pc, 0, 0, 1.0f, 1.0f, 0, 0, InputDevice.SOURCE_MOUSE, 0);
            injectEvent(event);
            event.recycle();
        } catch (Throwable t) {
            Ln.w("Scroll injection error: " + t.getMessage());
        }
    }

    private void handleCommand(DataInputStream in) throws IOException {
        byte cmd = in.readByte();
        switch (cmd) {
            case CMD_BACK:
                pressKeyCode(KeyEvent.KEYCODE_BACK);
                break;
            case CMD_HOME:
                pressKeyCode(KeyEvent.KEYCODE_HOME);
                break;
            case CMD_RECENTS:
                pressKeyCode(KeyEvent.KEYCODE_APP_SWITCH);
                break;
            case CMD_POWER:
                pressKeyCode(KeyEvent.KEYCODE_POWER);
                break;
            case CMD_VOLUME_UP:
                pressKeyCode(KeyEvent.KEYCODE_VOLUME_UP);
                break;
            case CMD_VOLUME_DOWN:
                pressKeyCode(KeyEvent.KEYCODE_VOLUME_DOWN);
                break;
            case CMD_SCREEN_OFF:
                try {
                    Runtime.getRuntime().exec("input keyevent 223"); // KEYCODE_SLEEP
                } catch (Exception ignored) {}
                break;
            case CMD_SCREEN_ON:
                try {
                    Runtime.getRuntime().exec("input keyevent 224"); // KEYCODE_WAKEUP
                } catch (Exception ignored) {}
                break;
        }
    }

    private void pressKeyCode(int keyCode) {
        long now = SystemClock.uptimeMillis();
        KeyEvent down = new KeyEvent(now, now, KeyEvent.ACTION_DOWN, keyCode, 0, 0,
                KeyCharacterMap.VIRTUAL_KEYBOARD, 0, 0, InputDevice.SOURCE_KEYBOARD);
        injectEvent(down);

        KeyEvent up = new KeyEvent(now, now, KeyEvent.ACTION_UP, keyCode, 0, 0,
                KeyCharacterMap.VIRTUAL_KEYBOARD, 0, 0, InputDevice.SOURCE_KEYBOARD);
        injectEvent(up);
    }

    private void injectEvent(InputEvent event) {
        try {
            injectInputEventMethod.invoke(inputManager, event, INJECT_INPUT_EVENT_MODE_ASYNC);
        } catch (Throwable t) {
            Ln.w("Failed to inject input event: " + t.getMessage());
        }
    }
}


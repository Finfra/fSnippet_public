#!/usr/bin/env python3
"""
right_command 트리거 키 전송 스크립트
CGEventTap이 감지하는 flagsChanged + NX_DEVICERCMDKEYMASK(0x10) 플래그를 직접 생성
"""
import time
import Quartz

# kCGEventFlagMaskCommand = 0x00100000
# NX_DEVICERCMDKEYMASK   = 0x00000010
RIGHT_CMD_FLAGS = 0x00100010
RIGHT_CMD_KEYCODE = 54

def post_right_cmd_down():
    event = Quartz.CGEventCreateKeyboardEvent(None, RIGHT_CMD_KEYCODE, True)
    Quartz.CGEventSetType(event, Quartz.kCGEventFlagsChanged)
    Quartz.CGEventSetFlags(event, RIGHT_CMD_FLAGS)
    Quartz.CGEventPost(Quartz.kCGHIDEventTap, event)

def post_right_cmd_up():
    event = Quartz.CGEventCreateKeyboardEvent(None, RIGHT_CMD_KEYCODE, False)
    Quartz.CGEventSetType(event, Quartz.kCGEventFlagsChanged)
    Quartz.CGEventSetFlags(event, 0)
    Quartz.CGEventPost(Quartz.kCGHIDEventTap, event)

if __name__ == "__main__":
    post_right_cmd_down()
    time.sleep(0.05)
    post_right_cmd_up()

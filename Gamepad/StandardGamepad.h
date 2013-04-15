#ifndef Gamepad_StandardGamepad_h
#define Gamepad_StandardGamepad_h

typedef enum {
  BUTTON_PAD_BOTTOM = 0,
  BUTTON_PAD_RIGHT = 1,
  BUTTON_PAD_LEFT = 2,
  BUTTON_PAD_TOP = 3,
  
  BUTTON_BUMPER_LEFT = 4,
  BUTTON_BUMPER_RIGHT = 5,
  
  BUTTON_TRIGGER_LEFT = 6,
  BUTTON_TRIGGER_RIGHT = 7,
  
  BUTTON_CENTER_BACK = 8, // back or select
  BUTTON_CENTER_FORWARD = 9, // forward or start
  
  BUTTON_STICK_LEFT = 10, // Clicking the analog sticks
  BUTTON_STICK_RIGHT = 11,
  
  BUTTON_DPAD_UP = 12,
  BUTTON_DPAD_DOWN = 13,
  BUTTON_DPAD_LEFT = 14,
  BUTTON_DPAD_RIGHT = 15,
  
  BUTTON_CENTER = 16, // Xbox or PS button in the center of the controller
  
  AXIS_LEFT_X = 0, // negative left, positive right
  AXIS_LEFT_Y = 1,
  AXIS_RIGHT_X = 2,
  AXIS_RIGHT_Y = 3,
} StandardGamepadMapping;

// This describes the button state for a 'standard gamepad' as per the remapping recommendations
// of the whatwg: https://dvcs.w3.org/hg/gamepad/raw-file/default/gamepad.html#remapping
typedef struct {
  float button[17];
  float axis[4];
} StandardGamepadData;

#endif

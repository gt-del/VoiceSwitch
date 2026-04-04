#ifndef VOICESWITCH_FFI_H
#define VOICESWITCH_FFI_H

#include <stdbool.h>
#include <stdint.h>

typedef enum {
    VSStateIdlePrimary = 0,
    VSStateVoiceMode = 1,
    VSStateCooldown = 2,
} VSState;

typedef enum {
    VSEventControlPressed = 0,
    VSEventControlReleased = 1,
    VSEventTypingDetected = 2,
    VSEventTypingKeyLetters = 3,
    VSEventTypingKeyNumbers = 4,
    VSEventTypingKeySpace = 5,
    VSEventTypingKeyDelete = 6,
    VSEventTypingKeyReturnKey = 7,
    VSEventManualSwitchDetected = 8,
    VSEventCooldownExpired = 9,
} VSEvent;

typedef enum {
    VSActionSwitchToPrimary = 0,
    VSActionSwitchToVoice = 1,
    VSActionEnterCooldown = 2,
    VSActionNoOp = 3,
} VSAction;

typedef enum {
    VSTimerKindVoiceActivationDelay = 0,
    VSTimerKindPrimaryReturnDelay = 1,
    VSTimerKindCooldown = 2,
} VSTimerKind;

typedef enum {
    VSErrorCodeOk = 0,
    VSErrorCodeInvalidArgument = 1,
    VSErrorCodeInvalidConfiguration = 2,
    VSErrorCodeInternal = 3,
} VSErrorCode;

typedef struct {
    double voice_activation_delay;
    double primary_return_delay;
    double cooldown_duration;
    bool allow_letters;
    bool allow_numbers;
    bool allow_space;
    bool allow_delete;
    bool allow_return_key;
} VSConfiguration;

typedef struct {
    char *trigger;
    char *reason;
    VSState source_state;
    VSState target_state;
} VSDiagnostic;

typedef struct {
    bool has_value;
    VSTimerKind kind;
    double delay_seconds;
} VSTimer;

typedef struct {
    VSState state;
    VSAction action;
    VSDiagnostic diagnostic;
    VSTimer timer;
} VSTransitionResult;

VSErrorCode vs_engine_transition(
    VSState current_state,
    VSEvent event,
    VSConfiguration configuration,
    VSTransitionResult *out_result
);

void vs_transition_result_free(VSTransitionResult *result);

const char *vs_error_message(VSErrorCode code);

#endif

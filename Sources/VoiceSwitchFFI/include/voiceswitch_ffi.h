#ifndef VOICESWITCH_FFI_H
#define VOICESWITCH_FFI_H

#include <stdbool.h>
#include <stdint.h>

typedef enum {
    VSStateIdlePrimary = 0,
    VSStateOptionPending = 1,
    VSStateVoiceActive = 2,
    VSStateCooldown = 3,
} VSState;

typedef enum {
    VSEventOptionPressed = 0,
    VSEventOptionReleased = 1,
    VSEventOptionWindowExpired = 2,
    VSEventTypingDetected = 3,
    VSEventTypingKeyLetters = 4,
    VSEventTypingKeyNumbers = 5,
    VSEventTypingKeySpace = 6,
    VSEventTypingKeyDelete = 7,
    VSEventTypingKeyReturnKey = 8,
    VSEventManualSwitchDetected = 9,
    VSEventCooldownExpired = 10,
    VSEventVoiceExitDelayElapsed = 11,
} VSEvent;

typedef enum {
    VSActionSwitchToPrimary = 0,
    VSActionSwitchToVoice = 1,
    VSActionEnterCooldown = 2,
    VSActionNoOp = 3,
} VSAction;

typedef enum {
    VSTimerKindOptionPendingWindow = 0,
    VSTimerKindVoiceExitDelay = 1,
    VSTimerKindCooldown = 2,
} VSTimerKind;

typedef enum {
    VSErrorCodeOk = 0,
    VSErrorCodeInvalidArgument = 1,
    VSErrorCodeInvalidConfiguration = 2,
    VSErrorCodeInternal = 3,
} VSErrorCode;

typedef struct {
    double option_pending_window;
    double cooldown_duration;
    double voice_exit_delay;
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

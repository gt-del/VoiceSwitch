#include "voiceswitch_ffi.h"

extern VSErrorCode rs_engine_transition(
    VSState current_state,
    VSEvent event,
    VSConfiguration configuration,
    VSTransitionResult *out_result
);
extern void rs_transition_result_free(VSTransitionResult *result);
extern const char *rs_error_message(VSErrorCode code);

VSErrorCode vs_engine_transition(
    VSState current_state,
    VSEvent event,
    VSConfiguration configuration,
    VSTransitionResult *out_result
) {
    return rs_engine_transition(current_state, event, configuration, out_result);
}

void vs_transition_result_free(VSTransitionResult *result) {
    rs_transition_result_free(result);
}

const char *vs_error_message(VSErrorCode code) {
    return rs_error_message(code);
}

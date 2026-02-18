package com.fidevelopment.onerule.autofill

import android.app.assist.AssistStructure
import android.os.CancellationSignal
import android.service.autofill.AutofillService
import android.service.autofill.FillCallback
import android.service.autofill.FillRequest
import android.service.autofill.FillResponse
import android.service.autofill.SaveCallback
import android.service.autofill.SaveRequest
import android.util.Log

class OneRuleAutofillService : AutofillService() {
    override fun onFillRequest(
        request: FillRequest,
        cancellationSignal: CancellationSignal,
        callback: FillCallback
    ) {
        // TODO(autofill-mvp): Parse AssistStructure, match trusted domain/app package,
        // and return secure datasets only after user-authenticated unlock.
        // Current scaffold intentionally returns no data.
        callback.onSuccess(FillResponse.Builder().build())
    }

    override fun onSaveRequest(request: SaveRequest, callback: SaveCallback) {
        // TODO(autofill-mvp): Securely prompt user to store new credentials.
        // Current scaffold performs no save behavior.
        callback.onSuccess()
    }
}

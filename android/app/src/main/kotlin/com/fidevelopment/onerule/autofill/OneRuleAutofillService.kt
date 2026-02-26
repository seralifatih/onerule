package com.fidevelopment.onerule.autofill

import android.app.assist.AssistStructure
import android.os.Build
import android.os.CancellationSignal
import android.service.autofill.AutofillService
import android.service.autofill.Dataset
import android.service.autofill.FillCallback
import android.service.autofill.FillRequest
import android.service.autofill.FillResponse
import android.service.autofill.SaveCallback
import android.service.autofill.SaveRequest
import android.util.Log
import android.view.autofill.AutofillValue
import android.widget.RemoteViews
import java.security.GeneralSecurityException
import javax.crypto.AEADBadTagException

class OneRuleAutofillService : AutofillService() {
    companion object {
        private const val TAG = "OneRuleAutofill"
    }

    override fun onFillRequest(
        request: FillRequest,
        cancellationSignal: CancellationSignal,
        callback: FillCallback
    ) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            returnNoResponse(callback, "Unsupported SDK for Autofill response.")
            return
        }

        val context = extractLatestRequestContext(request.fillContexts)
        if (context == null) {
            returnNoResponse(callback, "No AssistStructure context available for Autofill request.")
            return
        }

        if (context.passwordFieldId == null) {
            returnNoResponse(callback, "No fillable password field detected; returning null response.")
            return
        }

        val store: AutofillSecureStore
        val encryptedCredentials: List<StoredAutofillCredential>
        val sessionKey: ByteArray?
        try {
            store = AutofillSecureStore(applicationContext)
            encryptedCredentials = store.readCredentials()
            sessionKey = store.readSessionKeyBytes()
        } catch (error: Throwable) {
            Log.w(TAG, "Autofill store unavailable (vault locked/unavailable).", error)
            callback.onSuccess(null)
            return
        }

        if (encryptedCredentials.isEmpty()) {
            returnNoResponse(callback, "No credential snapshot cached for Autofill.")
            return
        }

        if (sessionKey == null) {
            returnNoResponse(callback, "Autofill session key unavailable; vault is likely locked.")
            return
        }

        val ranked = AutofillCredentialMatcher.rank(
            credentials = encryptedCredentials,
            packageName = context.packageName,
            webDomain = context.webDomain,
        )
        if (ranked.isEmpty()) {
            returnNoResponse(
                callback,
                "No mapped credentials for package=${context.packageName ?: "unknown"} domain=${context.webDomain ?: "unknown"}"
            )
            return
        }

        val responseBuilder = FillResponse.Builder()
        var datasetCount = 0
        try {
            ranked.forEach { encryptedCredential ->
                val displayName = AutofillEnvelopeCipher.decryptOrThrow(
                    encryptedCredential.displayNameEnc,
                    sessionKey,
                )
                val username = AutofillEnvelopeCipher.decryptOrThrow(
                    encryptedCredential.usernameEnc,
                    sessionKey,
                )
                val password = AutofillEnvelopeCipher.decryptOrThrow(
                    encryptedCredential.passwordEnc,
                    sessionKey,
                )

                val dataset = buildDataset(
                    displayName = displayName,
                    username = username,
                    password = password,
                    usernameFieldId = context.usernameFieldId,
                    passwordFieldId = context.passwordFieldId,
                )
                responseBuilder.addDataset(dataset)
                datasetCount++
            }
        } catch (tagError: AEADBadTagException) {
            Log.w(TAG, "AES-GCM authentication failed while decrypting autofill data.")
            callback.onFailure("Autofill authentication failed. Vault data may be tampered.")
            return
        } catch (securityError: GeneralSecurityException) {
            Log.w(TAG, "Unable to decrypt autofill payload.", securityError)
            callback.onFailure("Autofill decryption failed. Reopen OneRule and try again.")
            return
        }

        if (datasetCount == 0) {
            returnNoResponse(callback, "No datasets produced for Autofill request.")
            return
        }

        val response = responseBuilder.build()
        callback.onSuccess(response)
        Log.d(TAG, "Returned $datasetCount dataset(s) for Autofill request.")
    }

    override fun onSaveRequest(request: SaveRequest, callback: SaveCallback) {
        Log.d(TAG, "SaveRequest received; save flow is intentionally not implemented.")
        callback.onSuccess()
    }

    private fun buildDataset(
        displayName: String,
        username: String,
        password: String,
        usernameFieldId: android.view.autofill.AutofillId?,
        passwordFieldId: android.view.autofill.AutofillId,
    ): Dataset {
        val presentation = RemoteViews(packageName, android.R.layout.simple_list_item_1).apply {
            val subtitle = if (username.isBlank()) displayName else "$displayName • $username"
            setTextViewText(android.R.id.text1, subtitle)
        }

        return Dataset.Builder(presentation).apply {
            if (usernameFieldId != null && username.isNotBlank()) {
                setValue(usernameFieldId, AutofillValue.forText(username))
            }
            setValue(passwordFieldId, AutofillValue.forText(password))
        }.build()
    }

    private fun extractLatestRequestContext(
        contexts: List<android.service.autofill.FillContext>,
    ): ParsedAutofillRequest? {
        val lastContext = contexts.lastOrNull() ?: return null
        return AutofillStructureParser.parse(lastContext.structure)
    }

    private fun returnNoResponse(callback: FillCallback, reason: String) {
        Log.w(TAG, reason)
        callback.onSuccess(null)
    }
}

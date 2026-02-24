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
            callback.onSuccess(FillResponse.Builder().build())
            return
        }

        val context = extractLatestRequestContext(request.fillContexts)
        if (context == null) {
            Log.d(TAG, "No AssistStructure context available for Autofill request.")
            callback.onSuccess(FillResponse.Builder().build())
            return
        }

        if (context.passwordFieldId == null) {
            Log.d(TAG, "No password field detected; skipping autofill suggestions.")
            callback.onSuccess(FillResponse.Builder().build())
            return
        }

        val store = AutofillSecureStore(applicationContext)
        val encryptedCredentials = store.readCredentials()
        if (encryptedCredentials.isEmpty()) {
            Log.d(TAG, "No credential snapshot cached for Autofill.")
            callback.onSuccess(FillResponse.Builder().build())
            return
        }

        val sessionKey = store.readSessionKeyBytes()
        if (sessionKey == null) {
            Log.d(TAG, "Autofill session key unavailable; vault is likely locked.")
            callback.onSuccess(FillResponse.Builder().build())
            return
        }

        val ranked = AutofillCredentialMatcher.rank(
            credentials = encryptedCredentials,
            packageName = context.packageName,
            webDomain = context.webDomain,
        )
        if (ranked.isEmpty()) {
            Log.d(
                TAG,
                "No mapped credentials for package=${context.packageName ?: "unknown"} domain=${context.webDomain ?: "unknown"}"
            )
            callback.onSuccess(FillResponse.Builder().build())
            return
        }

        val responseBuilder = FillResponse.Builder()
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

        val response = responseBuilder.build()
        callback.onSuccess(response)
        Log.d(TAG, "Returned ${ranked.size} dataset(s) for Autofill request.")
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
}

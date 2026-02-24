package com.fidevelopment.onerule.autofill

import android.content.Context
import android.content.SharedPreferences
import android.util.Base64
import android.util.Log
import androidx.security.crypto.EncryptedSharedPreferences
import androidx.security.crypto.MasterKey
import org.json.JSONArray
import org.json.JSONObject
import java.util.Locale

data class StoredAutofillCredential(
    val id: String,
    val displayNameEnc: String,
    val usernameEnc: String,
    val passwordEnc: String,
    val domains: Set<String>,
    val packages: Set<String>,
)

class AutofillSecureStore(private val context: Context) {
    companion object {
        private const val TAG = "OneRuleAutofillStore"
        private const val PREF_FILE = "onerule_autofill_secure_store"
        private const val KEY_SNAPSHOT_JSON = "credential_snapshot_json"
        private const val KEY_SESSION_KEY_B64 = "session_key_base64"
    }

    private val prefs: SharedPreferences by lazy { createEncryptedPrefs(context) }

    fun saveCredentialSnapshot(snapshotJson: String) {
        prefs.edit().putString(KEY_SNAPSHOT_JSON, snapshotJson).apply()
    }

    fun readCredentials(): List<StoredAutofillCredential> {
        val payload = prefs.getString(KEY_SNAPSHOT_JSON, null) ?: return emptyList()
        return try {
            parseCredentials(payload)
        } catch (error: Throwable) {
            Log.w(TAG, "Invalid credential snapshot payload; ignoring cached snapshot.", error)
            emptyList()
        }
    }

    fun saveSessionKey(sessionKeyBase64: String) {
        prefs.edit().putString(KEY_SESSION_KEY_B64, sessionKeyBase64).apply()
    }

    fun clearSessionKey() {
        prefs.edit().remove(KEY_SESSION_KEY_B64).apply()
    }

    fun readSessionKeyBytes(): ByteArray? {
        val encoded = prefs.getString(KEY_SESSION_KEY_B64, null) ?: return null
        return try {
            Base64.decode(repadBase64Url(encoded), Base64.URL_SAFE)
        } catch (error: IllegalArgumentException) {
            Log.w(TAG, "Session key decode failed; clearing invalid key.")
            clearSessionKey()
            null
        }
    }

    private fun parseCredentials(payload: String): List<StoredAutofillCredential> {
        val root = JSONObject(payload)
        val array = root.optJSONArray("credentials") ?: JSONArray()
        val results = ArrayList<StoredAutofillCredential>(array.length())
        for (index in 0 until array.length()) {
            val item = array.optJSONObject(index) ?: continue

            val id = item.optString("id")
            val displayNameEnc = item.optString("displayNameEnc")
            val usernameEnc = item.optString("usernameEnc")
            val passwordEnc = item.optString("passwordEnc")

            if (id.isBlank() ||
                displayNameEnc.isBlank() ||
                usernameEnc.isBlank() ||
                passwordEnc.isBlank()
            ) {
                continue
            }

            val domains = parseStringSet(item.optJSONArray("domains"))
            val packages = parseStringSet(item.optJSONArray("packages"))
            results.add(
                StoredAutofillCredential(
                    id = id,
                    displayNameEnc = displayNameEnc,
                    usernameEnc = usernameEnc,
                    passwordEnc = passwordEnc,
                    domains = domains,
                    packages = packages,
                )
            )
        }
        return results
    }

    private fun parseStringSet(input: JSONArray?): Set<String> {
        if (input == null) return emptySet()
        val result = LinkedHashSet<String>(input.length())
        for (index in 0 until input.length()) {
            val value = input.optString(index).trim().lowercase(Locale.US)
            if (value.isNotEmpty()) {
                result.add(value)
            }
        }
        return result
    }

    private fun createEncryptedPrefs(context: Context): SharedPreferences {
        val masterKey = MasterKey.Builder(context)
            .setKeyScheme(MasterKey.KeyScheme.AES256_GCM)
            .build()

        @Suppress("DEPRECATION")
        return EncryptedSharedPreferences.create(
            context,
            PREF_FILE,
            masterKey,
            EncryptedSharedPreferences.PrefKeyEncryptionScheme.AES256_SIV,
            EncryptedSharedPreferences.PrefValueEncryptionScheme.AES256_GCM
        )
    }

    private fun repadBase64Url(value: String): String {
        val remainder = value.length % 4
        if (remainder == 0) return value
        return value + "=".repeat(4 - remainder)
    }
}

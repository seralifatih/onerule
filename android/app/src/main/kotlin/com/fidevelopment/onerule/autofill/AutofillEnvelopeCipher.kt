package com.fidevelopment.onerule.autofill

import android.util.Base64
import java.security.GeneralSecurityException
import javax.crypto.Cipher
import javax.crypto.spec.GCMParameterSpec
import javax.crypto.spec.SecretKeySpec

object AutofillEnvelopeCipher {
    private const val PREFIX = "or1"
    private const val VERSION_V2 = "v2"
    private const val ALGO_GCM = "gcm"
    private const val GCM_NONCE_BYTES = 12
    private const val GCM_TAG_BYTES = 16

    @Throws(GeneralSecurityException::class)
    fun decryptOrThrow(encodedEnvelope: String, sessionKey: ByteArray): String {
        val parts = encodedEnvelope.split(":")
        if (parts.size != 6 ||
            parts[0] != PREFIX ||
            parts[1] != VERSION_V2 ||
            parts[2] != ALGO_GCM
        ) {
            throw GeneralSecurityException("Unsupported credential envelope format.")
        }

        val nonce = decodeBase64Url(parts[3], "nonce")
        val cipherText = decodeBase64Url(parts[4], "ciphertext")
        val tag = decodeBase64Url(parts[5], "tag")

        if (nonce.size != GCM_NONCE_BYTES) {
            throw GeneralSecurityException("Invalid AES-GCM nonce length.")
        }
        if (tag.size != GCM_TAG_BYTES) {
            throw GeneralSecurityException("Invalid AES-GCM authentication tag length.")
        }

        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
        cipher.init(
            Cipher.DECRYPT_MODE,
            SecretKeySpec(sessionKey, "AES"),
            GCMParameterSpec(8 * GCM_TAG_BYTES, nonce),
        )

        val input = ByteArray(cipherText.size + tag.size)
        System.arraycopy(cipherText, 0, input, 0, cipherText.size)
        System.arraycopy(tag, 0, input, cipherText.size, tag.size)

        val plainBytes = cipher.doFinal(input)
        return plainBytes.toString(Charsets.UTF_8)
    }

    private fun decodeBase64Url(value: String, label: String): ByteArray {
        return try {
            Base64.decode(repadBase64Url(value), Base64.URL_SAFE)
        } catch (error: IllegalArgumentException) {
            throw GeneralSecurityException("Invalid base64url $label in credential envelope.", error)
        }
    }

    private fun repadBase64Url(value: String): String {
        val remainder = value.length % 4
        if (remainder == 0) return value
        return value + "=".repeat(4 - remainder)
    }
}

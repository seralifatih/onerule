package com.fidevelopment.onerule.autofill

import android.app.assist.AssistStructure
import android.text.InputType
import android.view.View
import android.view.autofill.AutofillId
import java.util.Locale

data class ParsedAutofillRequest(
    val packageName: String?,
    val webDomain: String?,
    val usernameFieldId: AutofillId?,
    val passwordFieldId: AutofillId?,
)

object AutofillStructureParser {
    fun parse(structure: AssistStructure): ParsedAutofillRequest {
        var usernameFieldId: AutofillId? = null
        var passwordFieldId: AutofillId? = null
        var webDomain: String? = null

        for (windowIndex in 0 until structure.windowNodeCount) {
            val rootNode = structure.getWindowNodeAt(windowIndex).rootViewNode ?: continue
            visitNode(rootNode) { node ->
                if (webDomain == null) {
                    webDomain = normalizeDomain(node.webDomain?.toString())
                }

                val autofillId = node.autofillId ?: return@visitNode
                if (passwordFieldId == null && isPasswordField(node)) {
                    passwordFieldId = autofillId
                    return@visitNode
                }
                if (usernameFieldId == null && isUsernameField(node)) {
                    usernameFieldId = autofillId
                }
            }
        }

        return ParsedAutofillRequest(
            packageName = structure.activityComponent?.packageName?.lowercase(Locale.US),
            webDomain = webDomain,
            usernameFieldId = usernameFieldId,
            passwordFieldId = passwordFieldId,
        )
    }

    private fun visitNode(
        node: AssistStructure.ViewNode,
        visitor: (AssistStructure.ViewNode) -> Unit,
    ) {
        visitor(node)
        for (childIndex in 0 until node.childCount) {
            val child = node.getChildAt(childIndex) ?: continue
            visitNode(child, visitor)
        }
    }

    private fun isPasswordField(node: AssistStructure.ViewNode): Boolean {
        val hints = node.autofillHints?.map { it.lowercase(Locale.US) }.orEmpty()
        if (hints.any { it.contains("password") }) return true
        if (hints.contains(View.AUTOFILL_HINT_PASSWORD)) return true

        val inputType = node.inputType
        if (inputType and InputType.TYPE_TEXT_VARIATION_PASSWORD ==
            InputType.TYPE_TEXT_VARIATION_PASSWORD
        ) {
            return true
        }
        if (inputType and InputType.TYPE_TEXT_VARIATION_WEB_PASSWORD ==
            InputType.TYPE_TEXT_VARIATION_WEB_PASSWORD
        ) {
            return true
        }
        if (inputType and InputType.TYPE_NUMBER_VARIATION_PASSWORD ==
            InputType.TYPE_NUMBER_VARIATION_PASSWORD
        ) {
            return true
        }

        val keywordBlob = buildKeywordBlob(node)
        return keywordBlob.contains("password") ||
            keywordBlob.contains("passwd") ||
            keywordBlob.contains("passcode")
    }

    private fun isUsernameField(node: AssistStructure.ViewNode): Boolean {
        if (isPasswordField(node)) return false

        val hints = node.autofillHints?.map { it.lowercase(Locale.US) }.orEmpty()
        if (hints.contains(View.AUTOFILL_HINT_USERNAME)) return true
        if (hints.contains(View.AUTOFILL_HINT_EMAIL_ADDRESS)) return true
        if (hints.any { it.contains("username") || it.contains("email") }) return true

        val keywordBlob = buildKeywordBlob(node)
        return keywordBlob.contains("username") ||
            keywordBlob.contains("email") ||
            keywordBlob.contains("login") ||
            keywordBlob.contains("userid") ||
            keywordBlob.contains("user_id")
    }

    private fun buildKeywordBlob(node: AssistStructure.ViewNode): String {
        return buildString {
            append(node.idEntry.orEmpty())
            append(" ")
            append(node.hint?.toString().orEmpty())
            append(" ")
            append(node.className.orEmpty())
        }.lowercase(Locale.US)
    }

    private fun normalizeDomain(rawValue: String?): String? {
        if (rawValue.isNullOrBlank()) return null
        var value = rawValue.trim().lowercase(Locale.US)
        if (value.startsWith("www.")) {
            value = value.removePrefix("www.")
        }
        return value.ifBlank { null }
    }
}

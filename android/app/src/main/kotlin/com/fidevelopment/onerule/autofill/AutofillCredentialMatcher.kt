package com.fidevelopment.onerule.autofill

import java.util.Locale

object AutofillCredentialMatcher {
    private val packageDomainHints: Map<String, Set<String>> = mapOf(
        "com.android.chrome" to setOf("google.com"),
        "com.android.vending" to setOf("google.com"),
        "com.facebook.katana" to setOf("facebook.com"),
        "com.instagram.android" to setOf("instagram.com"),
        "com.reddit.frontpage" to setOf("reddit.com"),
        "com.discord" to setOf("discord.com"),
        "com.twitter.android" to setOf("twitter.com", "x.com"),
        "com.snapchat.android" to setOf("snapchat.com"),
        "com.spotify.music" to setOf("spotify.com"),
        "com.netflix.mediaclient" to setOf("netflix.com"),
    )

    fun rank(
        credentials: List<StoredAutofillCredential>,
        packageName: String?,
        webDomain: String?,
    ): List<StoredAutofillCredential> {
        if (credentials.isEmpty()) return emptyList()

        val normalizedPackage = packageName?.lowercase(Locale.US)
        val normalizedWebDomain = normalizeDomain(webDomain)
        val packageDomains = domainsForPackage(normalizedPackage)

        val ranked = credentials.mapNotNull { credential ->
            val score = scoreCredential(
                credential = credential,
                packageName = normalizedPackage,
                packageDomains = packageDomains,
                webDomain = normalizedWebDomain,
            )
            if (score <= 0) return@mapNotNull null
            ScoredCredential(credential = credential, score = score)
        }

        if (ranked.isNotEmpty()) {
            return ranked
                .sortedByDescending { it.score }
                .map { it.credential }
                .take(6)
        }

        // Fallback: if request context has no useful hints, return recent subset.
        if (normalizedPackage == null && normalizedWebDomain == null) {
            return credentials.take(4)
        }
        return emptyList()
    }

    private fun scoreCredential(
        credential: StoredAutofillCredential,
        packageName: String?,
        packageDomains: Set<String>,
        webDomain: String?,
    ): Int {
        var score = 0

        if (packageName != null && credential.packages.contains(packageName)) {
            score += 120
        }
        if (webDomain != null) {
            if (credential.domains.contains(webDomain)) {
                score += 140
            } else if (credential.domains.any { isDomainFamilyMatch(it, webDomain) }) {
                score += 70
            }
        }
        if (packageDomains.isNotEmpty() &&
            credential.domains.any { domain -> packageDomains.any { hint -> isDomainFamilyMatch(domain, hint) } }
        ) {
            score += 80
        }

        return score
    }

    private fun domainsForPackage(packageName: String?): Set<String> {
        if (packageName == null) return emptySet()
        val domains = LinkedHashSet<String>()
        domains.addAll(packageDomainHints[packageName].orEmpty())

        val segments = packageName.split(".")
        if (segments.size >= 2) {
            val brandSegment = segments[1]
            if (brandSegment.length >= 3 && brandSegment != "android") {
                domains.add("$brandSegment.com")
            }
        }
        return domains.mapNotNull(::normalizeDomain).toSet()
    }

    private fun normalizeDomain(rawValue: String?): String? {
        if (rawValue.isNullOrBlank()) return null
        var value = rawValue.trim().lowercase(Locale.US)
        if (value.startsWith("www.")) {
            value = value.removePrefix("www.")
        }
        return value.ifBlank { null }
    }

    private fun isDomainFamilyMatch(a: String, b: String): Boolean {
        val first = normalizeDomain(a) ?: return false
        val second = normalizeDomain(b) ?: return false
        return first == second || first.endsWith(".$second") || second.endsWith(".$first")
    }

    private data class ScoredCredential(
        val credential: StoredAutofillCredential,
        val score: Int,
    )
}

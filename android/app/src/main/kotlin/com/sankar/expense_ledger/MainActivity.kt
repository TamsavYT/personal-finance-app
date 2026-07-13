package com.sankar.expense_ledger

import android.content.ActivityNotFoundException
import android.content.Intent
import android.net.Uri
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    private val channelName = "com.sankar.expense_ledger/upi"
    private val upiRequestCode = 7301
    private var pendingResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName).setMethodCallHandler { call, result ->
            when (call.method) {
                "pay" -> startUpiPayment(call.argument<String>("uri"), result)
                else -> result.notImplemented()
            }
        }
    }

    private fun startUpiPayment(uri: String?, result: MethodChannel.Result) {
        if (uri.isNullOrEmpty()) {
            result.error("INVALID_URI", "UPI URI missing", null)
            return
        }
        if (pendingResult != null) {
            result.error("ALREADY_IN_PROGRESS", "A UPI payment is already in progress", null)
            return
        }
        try {
            pendingResult = result
            startActivityForResult(Intent(Intent.ACTION_VIEW, Uri.parse(uri)), upiRequestCode)
        } catch (e: ActivityNotFoundException) {
            pendingResult = null
            result.error("NO_UPI_APP", "No UPI app found to handle the payment", null)
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != upiRequestCode) return
        val result = pendingResult ?: return
        pendingResult = null
        // UPI apps return the PSP response as a single string extra named "response",
        // e.g. "txnId=...&responseCode=...&Status=SUCCESS&txnRef=...&approvalRefNo=...".
        // Non-merchant (P2P) payments frequently return this extra empty or omit it
        // entirely even on a genuine success - callers must treat that as ambiguous,
        // not as failure.
        val response = data?.getStringExtra("response")
        result.success(mapOf("resultCode" to resultCode, "response" to response))
    }
}

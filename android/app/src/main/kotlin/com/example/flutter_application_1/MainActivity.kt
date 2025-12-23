package com.example.flutter_application_1

import android.Manifest
import android.bluetooth.BluetoothAdapter
import android.content.pm.PackageManager
import android.os.Build
import android.util.Log
import android.bluetooth.BluetoothSocket
import java.io.ByteArrayOutputStream
import java.util.UUID
import java.util.concurrent.Executors
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
	private val CHANNEL = "com.azima/printer"
	private val REQUEST_PRINT_PERMS = 1001
	private var pendingPrintArgs: Map<*, *>? = null
	private var pendingPrintResult: MethodChannel.Result? = null
	private var pendingMethod: String? = null
	private val printExecutor = Executors.newSingleThreadExecutor()

	override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
		super.configureFlutterEngine(flutterEngine)

		MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
			when (call.method) {
				"getBondedDevices" -> {
					try {
						val bluetoothAdapter: BluetoothAdapter? = BluetoothAdapter.getDefaultAdapter()
						if (bluetoothAdapter == null) {
							result.error("NO_BT", "Device has no Bluetooth adapter", null)
							return@setMethodCallHandler
						}
						val pairedDevices = bluetoothAdapter.bondedDevices
						val list: ArrayList<Map<String, String>> = ArrayList()
						if (pairedDevices != null) {
							for (device in pairedDevices) {
								val map = HashMap<String, String>()
								map["name"] = device.name ?: ""
								map["address"] = device.address
								list.add(map)
							}
						}
						result.success(list)
					} catch (e: SecurityException) {
						Log.e("MainActivity", "Permission denied getting bonded devices", e)
						result.error("PERMISSION", "Bluetooth permission denied", null)
					} catch (e: Exception) {
						Log.e("MainActivity", "Error getting bonded devices", e)
						result.error("ERROR", e.message, null)
					}
				}
				"printTest" -> {
					val args = call.arguments as? Map<*, *>
					val address = args?.get("address") as? String
					if (address.isNullOrBlank()) {
						result.error("NO_ADDRESS", "No Bluetooth address provided", null)
						return@setMethodCallHandler
					}

					// Check permissions; if missing, request and store pending call
					if (!hasPrintPermissions()) {
						pendingPrintArgs = args
						pendingPrintResult = result
						val perms = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
							arrayOf(Manifest.permission.BLUETOOTH_SCAN, Manifest.permission.BLUETOOTH_CONNECT)
						} else {
							arrayOf(Manifest.permission.ACCESS_FINE_LOCATION)
						}
						ActivityCompat.requestPermissions(this, perms, REQUEST_PRINT_PERMS)
						return@setMethodCallHandler
					}

					// Permissions granted; queue print on background executor and return immediately
					pendingMethod = "printTest"
					printExecutor.submit {
						val ok = performPrintSync(args)
						Log.i("MainActivity", "printTest completed (ok=$ok)")
					}
					result.success(true) // queued
				}
			"printOrder" -> {
				val args = call.arguments as? Map<*, *>
				// same address check
				val address = args?.get("address") as? String
				if (address.isNullOrBlank()) {
					result.error("NO_ADDRESS", "No Bluetooth address provided", null)
					return@setMethodCallHandler
				}

				if (!hasPrintPermissions()) {
					pendingPrintArgs = args
					pendingPrintResult = result
					pendingMethod = "printOrder"
					val perms = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
						arrayOf(Manifest.permission.BLUETOOTH_SCAN, Manifest.permission.BLUETOOTH_CONNECT)
					} else {
						arrayOf(Manifest.permission.ACCESS_FINE_LOCATION)
					}
					ActivityCompat.requestPermissions(this, perms, REQUEST_PRINT_PERMS)
					return@setMethodCallHandler
				}

				// Permissions granted; queue order print on background executor and return immediately
				pendingMethod = "printOrder"
				printExecutor.submit {
					val ok = performPrintOrderSync(args)
					Log.i("MainActivity", "printOrder completed (ok=$ok)")
				}
				result.success(true) // queued
			}
				else -> result.notImplemented()
			}
		}
	}

	private fun hasPrintPermissions(): Boolean {
		return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
			ContextCompat.checkSelfPermission(this, Manifest.permission.BLUETOOTH_CONNECT) == PackageManager.PERMISSION_GRANTED &&
					ContextCompat.checkSelfPermission(this, Manifest.permission.BLUETOOTH_SCAN) == PackageManager.PERMISSION_GRANTED
		} else {
			ContextCompat.checkSelfPermission(this, Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED
		}
	}

	private fun performPrint(args: Map<*, *>?, result: MethodChannel.Result) {
		val address = args?.get("address") as? String ?: run {
			result.error("NO_ADDRESS", "No Bluetooth address provided", null); return
		}
		val width = (args?.get("width") as? Int) ?: 58
		val businessName = (args?.get("businessName") as? String) ?: "Laundry App"
		val businessAddress = (args?.get("businessAddress") as? String) ?: ""
		val businessPhone = (args?.get("businessPhone") as? String) ?: ""

		var lastError: Exception? = null
		var attempt = 0
		val maxAttempts = 2
		while (attempt < maxAttempts) {
			attempt++
			var socket: BluetoothSocket? = null
			var out: java.io.OutputStream? = null
			try {
				val bluetoothAdapter: BluetoothAdapter? = BluetoothAdapter.getDefaultAdapter()
				if (bluetoothAdapter == null) {
					result.error("NO_BT", "Device has no Bluetooth adapter", null)
					return
				}
				val device = bluetoothAdapter.getRemoteDevice(address)
				val uuid = UUID.fromString("00001101-0000-1000-8000-00805F9B34FB")
				socket = try {
					device.createRfcommSocketToServiceRecord(uuid)
				} catch (e: Exception) {
					// fallback attempt using reflection to get a BluetoothSocket
					try {
						val m = device.javaClass.getMethod("createRfcommSocket", Int::class.javaPrimitiveType)
						m.invoke(device, 1) as? BluetoothSocket
					} catch (ex: Exception) {
						null
					}
				}

				bluetoothAdapter.cancelDiscovery()
				// small delay to allow adapter to settle
				Thread.sleep(120)
				socket?.connect()
				out = socket?.outputStream
				val bos = ByteArrayOutputStream()
				bos.write(byteArrayOf(0x1B, 0x40)) // init
				bos.write(byteArrayOf(0x1B, 0x61, 0x01)) // center
				bos.write((businessName + "\n").toByteArray())
				if (businessAddress.isNotBlank()) bos.write((businessAddress + "\n").toByteArray())
				if (businessPhone.isNotBlank()) bos.write(("Tel: " + businessPhone + "\n").toByteArray())
				bos.write(byteArrayOf(0x1B, 0x61, 0x00)) // left
				bos.write("------------------------------\n".toByteArray())
				bos.write("Sample Receipt\n".toByteArray())
				bos.write("Item 1    1 x 10.00\n".toByteArray())
				bos.write("Total     10.00\n".toByteArray())
				bos.write("\n\n\n".toByteArray())
				bos.write(byteArrayOf(0x1D, 0x56, 0x00))
				out?.write(bos.toByteArray())
				out?.flush()
				// small delay to ensure data is transmitted
				Thread.sleep(150)
				result.success(true)
				return
			} catch (se: SecurityException) {
				Log.e("MainActivity", "Permission denied printing", se)
				result.error("PERMISSION", "Bluetooth permission denied", null)
				return
			} catch (e: Exception) {
				Log.e("MainActivity", "Error printing attempt $attempt", e)
				lastError = e
				// try again after short delay unless last attempt
				if (attempt < maxAttempts) {
					try {
						Thread.sleep(200)
					} catch (ignored: InterruptedException) {
					}
				}
			} finally {
				// ensure streams and socket are closed
				try {
					out?.close()
				} catch (ignored: Exception) {
				}
				try {
					socket?.close()
				} catch (ignored: Exception) {
				}
				// small pause after close
				try {
					Thread.sleep(80)
				} catch (ignored: InterruptedException) {
				}
			}
		}
		// all attempts failed
		Log.e("MainActivity", "All print attempts failed", lastError)
		result.error("ERROR", lastError?.message ?: "Unknown error", null)
	}

	/**
	 * Synchronous printing helper that runs on a background thread. Returns true on success.
	 */
	private fun performPrintSync(args: Map<*, *>?): Boolean {
		val address = args?.get("address") as? String ?: return false
		val width = (args?.get("width") as? Int) ?: 58
		val businessName = (args?.get("businessName") as? String) ?: "Laundry App"
		val businessAddress = (args?.get("businessAddress") as? String) ?: ""
		val businessPhone = (args?.get("businessPhone") as? String) ?: ""

		var lastError: Exception? = null
		var attempt = 0
		val maxAttempts = 2
		while (attempt < maxAttempts) {
			attempt++
			var socket: BluetoothSocket? = null
			var out: java.io.OutputStream? = null
			try {
				val bluetoothAdapter: BluetoothAdapter? = BluetoothAdapter.getDefaultAdapter()
				if (bluetoothAdapter == null) {
					return false
				}
				val device = bluetoothAdapter.getRemoteDevice(address)
				val uuid = UUID.fromString("00001101-0000-1000-8000-00805F9B34FB")
				socket = try {
					device.createRfcommSocketToServiceRecord(uuid)
				} catch (e: Exception) {
					try {
						val m = device.javaClass.getMethod("createRfcommSocket", Int::class.javaPrimitiveType)
						m.invoke(device, 1) as? BluetoothSocket
					} catch (ex: Exception) {
						null
					}
				}

				bluetoothAdapter.cancelDiscovery()
				Thread.sleep(120)
				socket?.connect()
				out = socket?.outputStream
				val bos = ByteArrayOutputStream()
				bos.write(byteArrayOf(0x1B, 0x40)) // init
				bos.write(byteArrayOf(0x1B, 0x61, 0x01)) // center
				bos.write((businessName + "\n").toByteArray())
				if (businessAddress.isNotBlank()) bos.write((businessAddress + "\n").toByteArray())
				if (businessPhone.isNotBlank()) bos.write(("Tel: " + businessPhone + "\n").toByteArray())
				bos.write(byteArrayOf(0x1B, 0x61, 0x00)) // left
				bos.write("------------------------------\n".toByteArray())
				bos.write("Sample Receipt\n".toByteArray())
				bos.write("Item 1    1 x 10.00\n".toByteArray())
				bos.write("Total     10.00\n".toByteArray())
				bos.write("\n\n\n".toByteArray())
				bos.write(byteArrayOf(0x1D, 0x56, 0x00))
				out?.write(bos.toByteArray())
				out?.flush()
				Thread.sleep(150)
				return true
			} catch (se: SecurityException) {
				Log.e("MainActivity", "Permission denied printing", se)
				return false
			} catch (e: Exception) {
				Log.e("MainActivity", "Error printing attempt $attempt", e)
				lastError = e
				if (attempt < maxAttempts) {
					try { Thread.sleep(200) } catch (ignored: InterruptedException) {}
				}
			} finally {
				try { out?.close() } catch (ignored: Exception) {}
				try { socket?.close() } catch (ignored: Exception) {}
				try { Thread.sleep(80) } catch (ignored: InterruptedException) {}
			}
		}
		Log.e("MainActivity", "All print attempts failed", lastError)
		return false
	}

	private fun performPrintOrder(args: Map<*, *>?, result: MethodChannel.Result) {
		val orderMap = args?.get("order") as? Map<*, *> ?: run {
			result.error("NO_ORDER", "Order data missing", null); return
		}
		val businessName = (args?.get("businessName") as? String) ?: "Laundry App"
		val businessAddress = (args?.get("businessAddress") as? String) ?: ""
		val businessPhone = (args?.get("businessPhone") as? String) ?: ""
		val address = (args["address"] as? String) ?: run { result.error("NO_ADDRESS", "No address", null); return }

		// Build ESC/POS bytes for order
		val bosAll = ByteArrayOutputStream()
		try {
			bosAll.write(byteArrayOf(0x1B, 0x40)) // init
			bosAll.write(byteArrayOf(0x1B, 0x61, 0x01)) // center
			bosAll.write((businessName + "\n").toByteArray())
			if (businessAddress.isNotBlank()) bosAll.write((businessAddress + "\n").toByteArray())
			if (businessPhone.isNotBlank()) bosAll.write(("Tel: " + businessPhone + "\n").toByteArray())
			bosAll.write(byteArrayOf(0x1B, 0x61, 0x00)) // left
			bosAll.write("--------------------------------\n".toByteArray())
			// Order header
			val orderId = orderMap["id"]?.toString() ?: ""
			val customer = orderMap["customerName"]?.toString() ?: ""
			val orderDateRaw = orderMap["orderDate"]?.toString() ?: ""
			val paymentMethod = orderMap["paymentMethod"]?.toString() ?: ""
			// Format date and time: date as yyyy-MM-dd, time as HH:mm (only hour:minute)
			var dateStr = orderDateRaw
			var timeStr = ""
			try {
				val odt = java.time.OffsetDateTime.parse(orderDateRaw)
				val dateFmt = java.time.format.DateTimeFormatter.ofPattern("yyyy-MM-dd")
				val timeFmt = java.time.format.DateTimeFormatter.ofPattern("HH:mm")
				dateStr = odt.toLocalDate().format(dateFmt)
				timeStr = odt.toLocalTime().format(timeFmt)
			} catch (e: Exception) {
				try {
					val ldt = java.time.LocalDateTime.parse(orderDateRaw)
					val dateFmt = java.time.format.DateTimeFormatter.ofPattern("yyyy-MM-dd")
					val timeFmt = java.time.format.DateTimeFormatter.ofPattern("HH:mm")
					dateStr = ldt.toLocalDate().format(dateFmt)
					timeStr = ldt.toLocalTime().format(timeFmt)
				} catch (e2: Exception) {
					// If parsing fails, try to extract date and HH:mm from common ISO-like strings
					try {
						if (orderDateRaw.contains("T")) {
							val parts = orderDateRaw.split("T")
							if (parts.isNotEmpty()) {
								dateStr = parts[0]
							}
							if (parts.size > 1) {
								val timePart = parts[1]
								val m = Regex("^(\\d{2}:\\d{2})").find(timePart)
								if (m != null) timeStr = m.groupValues[1]
							}
						} else {
							val m = Regex("(\\d{2}:\\d{2})").find(orderDateRaw)
							if (m != null) timeStr = m.groupValues[1]
						}
					} catch (e3: Exception) {
						// final fallback: leave raw
					}
				}
			}
			bosAll.write(("Order: #$orderId\n").toByteArray())
			bosAll.write(("Nama: $customer\n").toByteArray())
			bosAll.write(("Tanggal: $dateStr ${if (timeStr.isNotEmpty()) timeStr else ""}\n").toByteArray())
			bosAll.write(("Metode: $paymentMethod\n").toByteArray())
			bosAll.write("--------------------------------\n".toByteArray())
			// Items
			@Suppress("UNCHECKED_CAST")
			val items = orderMap["items"] as? List<Map<*, *>> ?: emptyList()
			for (it in items) {
				val name = it["itemName"]?.toString() ?: ""
				val qty = (it["quantity"] as? Number)?.toInt() ?: 0
				val price = (it["price"] as? Number)?.toInt() ?: 0
				val line = String.format("%-16s %3d x %7d\n", name.take(16), qty, price)
				bosAll.write(line.toByteArray())
				if (it["note"] != null) {
					bosAll.write(("  * ${it["note"]}\n").toByteArray())
				}
			}
			bosAll.write("--------------------------------\n".toByteArray())
			val total = orderMap["totalAmount"]?.toString() ?: "0"
			bosAll.write(("Total: Rp$total\n").toByteArray())
			bosAll.write("\n\n\n".toByteArray())
			bosAll.write(byteArrayOf(0x1D, 0x56, 0x00)) // cut
		} catch (e: Exception) {
			result.error("ERROR", "Failed build receipt: ${e.message}", null)
			return
		}

		// send bytes using similar retry/cleanup as performPrint
		var lastError: Exception? = null
		val maxAttempts = 2
		for (attempt in 1..maxAttempts) {
			var socket: BluetoothSocket? = null
			var out: java.io.OutputStream? = null
			try {
				val bluetoothAdapter: BluetoothAdapter? = BluetoothAdapter.getDefaultAdapter()
				if (bluetoothAdapter == null) { result.error("NO_BT", "Device has no Bluetooth adapter", null); return }
				val device = bluetoothAdapter.getRemoteDevice(address)
				val uuid = UUID.fromString("00001101-0000-1000-8000-00805F9B34FB")
				socket = try { device.createRfcommSocketToServiceRecord(uuid) } catch (e: Exception) {
					try { val m = device.javaClass.getMethod("createRfcommSocket", Int::class.javaPrimitiveType); m.invoke(device, 1) as? BluetoothSocket } catch (ex: Exception) { null }
				}
				bluetoothAdapter.cancelDiscovery()
				Thread.sleep(120)
				socket?.connect()
				out = socket?.outputStream
				out?.write(bosAll.toByteArray())
				out?.flush()
				Thread.sleep(150)
				result.success(true)
				return
			} catch (e: Exception) {
				lastError = e
				Log.e("MainActivity", "Error printing order attempt $attempt", e)
				if (attempt < maxAttempts) {
					try { Thread.sleep(200) } catch (_: InterruptedException) {}
				}
			} finally {
				try { out?.close() } catch (_: Exception) {}
				try { socket?.close() } catch (_: Exception) {}
				try { Thread.sleep(80) } catch (_: InterruptedException) {}
			}
		}
		Log.e("MainActivity", "All printOrder attempts failed", lastError)
		result.error("ERROR", lastError?.message ?: "Unknown error", null)
	}

	private fun performPrintOrderSync(args: Map<*, *>?): Boolean {
		val orderMap = args?.get("order") as? Map<*, *> ?: return false
		val businessName = (args?.get("businessName") as? String) ?: "Laundry App"
		val businessAddress = (args?.get("businessAddress") as? String) ?: ""
		val businessPhone = (args?.get("businessPhone") as? String) ?: ""
		val address = (args["address"] as? String) ?: return false

		val bosAll = ByteArrayOutputStream()
		try {
			bosAll.write(byteArrayOf(0x1B, 0x40)) // init
			bosAll.write(byteArrayOf(0x1B, 0x61, 0x01)) // center
			bosAll.write((businessName + "\n").toByteArray())
			if (businessAddress.isNotBlank()) bosAll.write((businessAddress + "\n").toByteArray())
			if (businessPhone.isNotBlank()) bosAll.write(("Tel: " + businessPhone + "\n").toByteArray())
			bosAll.write(byteArrayOf(0x1B, 0x61, 0x00)) // left
			bosAll.write("--------------------------------\n".toByteArray())
			val orderId = orderMap["id"]?.toString() ?: ""
			val customer = orderMap["customerName"]?.toString() ?: ""
			val orderDateRaw = orderMap["orderDate"]?.toString() ?: ""
			val paymentMethod = orderMap["paymentMethod"]?.toString() ?: ""
			var dateStr = orderDateRaw
			var timeStr = ""
			try {
				val odt = java.time.OffsetDateTime.parse(orderDateRaw)
				val dateFmt = java.time.format.DateTimeFormatter.ofPattern("yyyy-MM-dd")
				val timeFmt = java.time.format.DateTimeFormatter.ofPattern("HH:mm")
				dateStr = odt.toLocalDate().format(dateFmt)
				timeStr = odt.toLocalTime().format(timeFmt)
			} catch (e: Exception) {
				try {
					val ldt = java.time.LocalDateTime.parse(orderDateRaw)
					val dateFmt = java.time.format.DateTimeFormatter.ofPattern("yyyy-MM-dd")
					val timeFmt = java.time.format.DateTimeFormatter.ofPattern("HH:mm")
					dateStr = ldt.toLocalDate().format(dateFmt)
					timeStr = ldt.toLocalTime().format(timeFmt)
				} catch (e2: Exception) {
					try {
						if (orderDateRaw.contains("T")) {
							val parts = orderDateRaw.split("T")
							if (parts.isNotEmpty()) {
								dateStr = parts[0]
							}
							if (parts.size > 1) {
								val timePart = parts[1]
								val m = Regex("^(\\d{2}:\\d{2})").find(timePart)
								if (m != null) timeStr = m.groupValues[1]
							}
						} else {
							val m = Regex("(\\d{2}:\\d{2})").find(orderDateRaw)
							if (m != null) timeStr = m.groupValues[1]
						}
					} catch (e3: Exception) {
					}
				}
			}
			bosAll.write(("Order: #$orderId\n").toByteArray())
			bosAll.write(("Nama: $customer\n").toByteArray())
			bosAll.write(("Tanggal: $dateStr ${if (timeStr.isNotEmpty()) timeStr else ""}\n").toByteArray())
			bosAll.write(("Metode: $paymentMethod\n").toByteArray())
			bosAll.write("--------------------------------\n".toByteArray())
			@Suppress("UNCHECKED_CAST")
			val items = orderMap["items"] as? List<Map<*, *>> ?: emptyList()
			for (it in items) {
				val name = it["itemName"]?.toString() ?: ""
				val qty = (it["quantity"] as? Number)?.toInt() ?: 0
				val price = (it["price"] as? Number)?.toInt() ?: 0
				val line = String.format("%-16s %3d x %7d\n", name.take(16), qty, price)
				bosAll.write(line.toByteArray())
				if (it["note"] != null) {
					bosAll.write(("  * ${it["note"]}\n").toByteArray())
				}
			}
			bosAll.write("--------------------------------\n".toByteArray())
			val total = orderMap["totalAmount"]?.toString() ?: "0"
			bosAll.write(("Total: Rp$total\n").toByteArray())
			bosAll.write("\n\n\n".toByteArray())
			bosAll.write(byteArrayOf(0x1D, 0x56, 0x00)) // cut
		} catch (e: Exception) {
			return false
		}

		var lastError: Exception? = null
		val maxAttempts = 2
		for (attempt in 1..maxAttempts) {
			var socket: BluetoothSocket? = null
			var out: java.io.OutputStream? = null
			try {
				val bluetoothAdapter: BluetoothAdapter? = BluetoothAdapter.getDefaultAdapter()
				if (bluetoothAdapter == null) return false
				val device = bluetoothAdapter.getRemoteDevice(address)
				val uuid = UUID.fromString("00001101-0000-1000-8000-00805F9B34FB")
				socket = try { device.createRfcommSocketToServiceRecord(uuid) } catch (e: Exception) {
					try { val m = device.javaClass.getMethod("createRfcommSocket", Int::class.javaPrimitiveType); m.invoke(device, 1) as? BluetoothSocket } catch (ex: Exception) { null }
				}
				bluetoothAdapter.cancelDiscovery()
				Thread.sleep(120)
				socket?.connect()
				out = socket?.outputStream
				out?.write(bosAll.toByteArray())
				out?.flush()
				Thread.sleep(150)
				return true
			} catch (e: Exception) {
				lastError = e
				Log.e("MainActivity", "Error printing order attempt $attempt", e)
				if (attempt < maxAttempts) { try { Thread.sleep(200) } catch (_: InterruptedException) {} }
			} finally {
				try { out?.close() } catch (_: Exception) {}
				try { socket?.close() } catch (_: Exception) {}
				try { Thread.sleep(80) } catch (_: InterruptedException) {}
			}
		}
		Log.e("MainActivity", "All printOrder attempts failed", lastError)
		return false
	}

	override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
		super.onRequestPermissionsResult(requestCode, permissions, grantResults)
		if (requestCode == REQUEST_PRINT_PERMS) {
			val granted = grantResults.isNotEmpty() && grantResults.all { it == PackageManager.PERMISSION_GRANTED }
			if (granted && pendingPrintArgs != null && pendingPrintResult != null) {
				// Queue the pending print job rather than executing on platform thread
				if (pendingMethod == "printTest") {
					printExecutor.submit {
						val ok = performPrintSync(pendingPrintArgs)
						Log.i("MainActivity", "Pending printTest completed (ok=$ok)")
					}
					pendingPrintResult?.success(true)
				} else if (pendingMethod == "printOrder") {
					printExecutor.submit {
						val ok = performPrintOrderSync(pendingPrintArgs)
						Log.i("MainActivity", "Pending printOrder completed (ok=$ok)")
					}
					pendingPrintResult?.success(true)
				} else {
					// default: acknowledge
					pendingPrintResult?.success(true)
				}
			} else {
				pendingPrintResult?.error("PERMISSION", "Required permissions not granted", null)
			}
			pendingPrintArgs = null
			pendingPrintResult = null
		}
	}
}

/********************************************************************************
 * Copyright (c) 2018-2020 Contributors to the Gamma project
 *
 * All rights reserved. This program and the accompanying materials
 * are made available under the terms of the Eclipse Public License v1.0
 * which accompanies this distribution, and is available at
 * http://www.eclipse.org/legal/epl-v10.html
 *
 * SPDX-License-Identifier: EPL-1.0
 ********************************************************************************/
package hu.bme.mit.gamma.theta.verification

import hu.bme.mit.gamma.statechart.interface_.Package
import hu.bme.mit.gamma.trace.model.ExecutionTrace
import hu.bme.mit.gamma.util.FileUtil
import hu.bme.mit.gamma.verification.result.ThreeStateBoolean
import hu.bme.mit.gamma.verification.util.AbstractVerifier
import java.io.File
import java.util.Scanner
import java.util.logging.Level

import static com.google.common.base.Preconditions.checkState

class ThetaVerifier extends AbstractVerifier {
	
	protected final extension ThetaQueryAdapter thetaQueryAdapter = ThetaQueryAdapter.INSTANCE
	protected final extension ThetaValidator thetaValidator = ThetaValidator.INSTANCE
	
	final String ENVIRONMENT_VARIABLE_FOR_THETA_JAR = "THETA_XSTS_CLI_PATH"
	
	final String SAFE = "SafetyResult Safe"
	final String UNSAFE = "SafetyResult Unsafe"
	
	override ExecutionTrace verifyQuery(Object traceability, String parameters, File modelFile,
			String query, boolean log, boolean storeOutput) {
		var ExecutionTrace trace = null
		for (singleQuery : query.split(System.lineSeparator).reject[it.nullOrEmpty]) {
			// Supporting multiple queries in separate files
			val parsedQuery = singleQuery.adaptQuery
			val wrappedQuery = '''
				prop {
					�parsedQuery�
				}
			'''
			val newTrace = super.verifyQuery(traceability, parameters, modelFile, wrappedQuery, log, storeOutput)
			if (trace === null) {
				trace = newTrace
			}
			else {
				trace.extend(newTrace)
			}
		}
		return trace
	}
	
	override ExecutionTrace verifyQuery(Object traceability, String parameters, File modelFile,
			File queryFile, boolean log, boolean storeOutput) {
		var Scanner resultReader = null
		var Scanner traceFileScanner = null
		try {
			ENVIRONMENT_VARIABLE_FOR_THETA_JAR.validate
			// The 'THETA_XSTS_CLI_PATH' environment variable has to be set to the respective file path
			val jar = System.getenv(ENVIRONMENT_VARIABLE_FOR_THETA_JAR)
			// java -jar %THETA_XSTS_CLI_PATH% --model trafficlight.xsts --property red_green.prop
			val traceFile = new File(modelFile.traceFile)
			traceFile.delete // So no invalid/old cex is parsed if this actual process does not generate one 
			val command = '''java -jar �jar.escapePath� �parameters� --model �modelFile.canonicalPath.escapePath� --property �queryFile.canonicalPath.escapePath� --cex �traceFile.canonicalPath.escapePath�'''
			// Executing the command
			logger.log(Level.INFO, "Executing command: " + command)
			process = Runtime.getRuntime().exec(command)
			val outputStream = process.inputStream
			resultReader = new Scanner(outputStream)
			var line = ""
			while (resultReader.hasNext) {
				// (SafetyResult Safe) or (SafetyResult Unsafe)
				line = resultReader.nextLine
				if (log) {
					logger.log(Level.INFO, line)
				}
			}
			// Variable 'line' contains the last line of the output - the result
			if (line.contains(SAFE)) {
				super.result = ThreeStateBoolean.TRUE
			}
			else if (line.contains(UNSAFE)) {
				super.result = ThreeStateBoolean.FALSE
			}
			else {
				// Some kind of error
				throw new IllegalArgumentException(line)
			}
			// Adapting result
			super.result = super.result.adaptResult
			if (!traceFile.exists) {
				// No proof/counterexample
				return null;
			}
			val gammaPackage = traceability as Package
			traceFileScanner = new Scanner(traceFile)
			val backAnnotator = new TraceBackAnnotator(gammaPackage, traceFileScanner)
			return backAnnotator.execute
		} finally {
			if (resultReader !== null) {
				resultReader.close
			}
			if (traceFileScanner !== null) {
				traceFileScanner.close
			}
		}
	}
	
	override getTemporaryQueryFilename(File modelFile) {
		return "." + modelFile.extensionlessName + ".prop"
	}
	
	def getTraceFile(File modelFile) {
		return modelFile.parent + File.separator + modelFile.extensionlessName + ".cex";
	}
	
}

class ThetaQueryAdapter {
	public static ThetaQueryAdapter INSTANCE = new ThetaQueryAdapter
	private new() {}
	// Singleton
	final String EF = "E<>"
	final String AG = "A[]"
	
	extension FileUtil fileUtil = FileUtil.INSTANCE
	boolean invert;
	
	def adaptQuery(File queryFile) {
		return queryFile.loadString.adaptQuery
	}
	
	def adaptQuery(String query) {
		if (query.startsWith("E<>")) {
			invert = true;
			return "!(" + query.substring(EF.length) + ")"
		}
		if (query.startsWith("A[]")) {
			invert = false;
			return query.substring(AG.length)
		}
		throw new IllegalArgumentException("Not supported operator: " + query)
	}
	
	def adaptResult(ThreeStateBoolean thetaResult) {
		if (thetaResult === null) {
			// If the process is cancelled, the result will be null
			return ThreeStateBoolean.UNDEF
		}
		if (invert) {
			return thetaResult.opposite
		}
		return thetaResult
	}
	
}

class ThetaValidator {
	public static ThetaValidator INSTANCE = new ThetaValidator
	private new() {}
	// Singleton
	
	def validate(String thetaEnvironmentVariable) {
		val jar = System.getenv(thetaEnvironmentVariable)
		val thetaJarFile = new File(jar)
		checkState(thetaJarFile.exists && !thetaJarFile.directory, "The environment variable " + 
				thetaEnvironmentVariable + " does not refer to a valid jar file: " + jar)
	}
	
}

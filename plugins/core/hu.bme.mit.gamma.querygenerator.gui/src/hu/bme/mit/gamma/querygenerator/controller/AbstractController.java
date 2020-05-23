package hu.bme.mit.gamma.querygenerator.controller;

import java.io.File;
import java.util.AbstractMap;
import java.util.ArrayList;
import java.util.Collections;
import java.util.List;
import java.util.Map;
import java.util.logging.Logger;

import javax.swing.JComboBox;

import org.eclipse.core.resources.IFile;
import org.eclipse.core.resources.IResource;
import org.eclipse.emf.common.util.URI;

import hu.bme.mit.gamma.querygenerator.AbstractQueryGenerator;
import hu.bme.mit.gamma.querygenerator.application.View;
import hu.bme.mit.gamma.querygenerator.gui.util.GeneratedTestVerifier;
import hu.bme.mit.gamma.querygenerator.gui.util.GuiVerifier;
import hu.bme.mit.gamma.querygenerator.operators.TemporalOperator;
import hu.bme.mit.gamma.util.GammaEcoreUtil;

public abstract class AbstractController {
	// View
	protected View view;
	// Has to be set by subclass
	protected AbstractQueryGenerator queryGenerator;
	// Indicates the actual verification process
	protected volatile GuiVerifier verifier;
	// Indicates the actual test generation process
	protected volatile GeneratedTestVerifier generatedTestVerifier;
	
	// The location of the model on which this query generator is opened
	// E.g.: F:/eclipse_ws/sc_analysis_comp_oxy/runtime-New_configuration/hu.bme.mit.inf.gamma.tests/model/TestOneComponent.gsm
	protected IFile file;
	
	// Util
	protected GammaEcoreUtil ecoreUtil = new GammaEcoreUtil();
	protected Logger logger = Logger.getLogger("GammaLogger");

	protected final String TEST_GEN_FOLDER_NAME = "test-gen";
	protected final String TRACE_FOLDER_NAME = "trace";
	
	/**
	 * Starts the verification process with the given query.
	 */
	public abstract void verify(String query);
	
	/**
	 * Cancels the actual verification process. Returns true if a process has been cancelled.
	 */
	public abstract boolean cancelVerification();
	
	/**
	 * Executes the generated queries.
	 */
	public abstract void executeGeneratedQueries();
	
	// View setting
	
	public void initSelectorWithStates(JComboBox<String> selector) {
		fillComboBox(selector, queryGenerator.getStateNames());
	}
	
	public void initSelectorWithVariables(JComboBox<String> selector) {
		fillComboBox(selector, queryGenerator.getVariableNames());
	}
	
	public void initSelectorWithEvents(JComboBox<String> selector) {
		List<String> systemOutEventNames = queryGenerator.getSystemOutEventNames();
		systemOutEventNames.addAll(queryGenerator.getSystemOutEventParameterNames());
		fillComboBox(selector, systemOutEventNames);
	}
	
    private void fillComboBox(JComboBox<String> selector, List<String> entryList) {
    	Collections.sort(entryList);
    	for (String item : entryList) {
    		selector.addItem(queryGenerator.unwrap(item));
    	}
    }
    
	public String parseRegularQuery(String text, String temporalOperator) {
		TemporalOperator operator = TemporalOperator.valueOf(
				temporalOperator.replaceAll(" ", "_").replace("\"", "").toUpperCase());
		return queryGenerator.parseRegularQuery(text, operator);
	}
	
	public String parseLeadsToQuery(String first, String second) {
		return queryGenerator.parseLeadsToQuery(first, second);
	}
	
	// Parameter and file manipulation
	
	public GuiVerifier getVerifier() {
		return verifier;
	}
	
	public void setVerifier(GuiVerifier verifier) {
		this.verifier = verifier;
	}
	
	public GeneratedTestVerifier getGeneratedTestVerifier() {
		return generatedTestVerifier;
	}
	
	public void setGeneratedTestVerifier(GeneratedTestVerifier generatedTestVerifier) {
		this.generatedTestVerifier = generatedTestVerifier;
	}
	
    /**
     * Returns the next valid name for the file containing the back-annotation.
     */
    public Map.Entry<String, Integer> getFileName(String fileExtension) {
    	final String TRACE_FILE_NAME = "ExecutionTrace";
    	List<Integer> usedIds = new ArrayList<Integer>();
    	File traceFile = new File(getTraceFolder());
    	traceFile.mkdirs();
    	// Searching the trace folder for highest id
    	for (File file: new File(getTraceFolder()).listFiles()) {
    		if (file.getName().matches(TRACE_FILE_NAME + "[0-9]+\\..*")) {
    			String id = file.getName().substring(TRACE_FILE_NAME.length(), file.getName().length() - ("." + fileExtension).length());
    			usedIds.add(Integer.parseInt(id));
    		}
    	}
    	if (usedIds.isEmpty()) {
    		return new AbstractMap.SimpleEntry<String, Integer>(TRACE_FILE_NAME + "0." + fileExtension, 0);
    	}
    	Collections.sort(usedIds);
    	Integer biggestId = usedIds.get(usedIds.size() - 1);
    	return new AbstractMap.SimpleEntry<String, Integer>(
    			TRACE_FILE_NAME + (biggestId + 1) + "." + fileExtension, (biggestId + 1));
    }
    
    protected String getLocation(IResource file) {
    	return URI.decode(file.getLocation().toString());
    }
    
    protected String getParentFolder() {
		return getLocation(file.getParent());
	}
    
    public String getBasePackage() {
		return file.getProject().getName().toLowerCase();
	}
    
    public String getTestGenFolder() {
		return getLocation(file.getProject()) + File.separator + TEST_GEN_FOLDER_NAME;
	}
    
    public String getTraceFolder() {
		return getLocation(file.getProject()) + File.separator + TRACE_FOLDER_NAME;
	}
	
	public abstract String getParameters();
	public abstract String getModelFile();
	public abstract String getGeneratedQueryFile();
	public abstract Object getTraceability();
	
}

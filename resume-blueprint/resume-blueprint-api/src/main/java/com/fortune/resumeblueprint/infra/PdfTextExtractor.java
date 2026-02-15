package com.fortune.resumeblueprint.infra;

import org.apache.pdfbox.pdmodel.PDDocument;
import org.apache.pdfbox.text.PDFTextStripper;
import org.springframework.stereotype.Component;

import java.io.IOException;
import java.io.InputStream;

/**
 * Utility class for extracting text from PDF files.
 * Currently supports text-based PDFs only (no OCR for scanned PDFs).
 */
@Component
public class PdfTextExtractor {
    
    /**
     * Extract text from PDF input stream.
     * 
     * @param in PDF input stream
     * @return Extracted text (normalized: control characters removed, whitespace compressed, trimmed)
     * @throws IOException if PDF cannot be read
     */
    public String extract(InputStream in) throws IOException {
        try (PDDocument document = PDDocument.load(in)) {
            PDFTextStripper stripper = new PDFTextStripper();
            String text = stripper.getText(document);
            
            // Normalize: remove control characters, compress whitespace, trim
            return normalize(text);
        }
    }
    
    /**
     * Normalize extracted text:
     * - Remove control characters (except newline, tab)
     * - Compress multiple whitespace to single space
     * - Trim leading/trailing whitespace
     */
    private String normalize(String text) {
        if (text == null) {
            return "";
        }
        
        // Remove control characters (keep \n, \r, \t)
        text = text.replaceAll("[\\x00-\\x08\\x0B\\x0C\\x0E-\\x1F\\x7F]", "");
        
        // Compress multiple whitespace (including newlines) to single space
        text = text.replaceAll("\\s+", " ");
        
        // Trim
        return text.trim();
    }
}

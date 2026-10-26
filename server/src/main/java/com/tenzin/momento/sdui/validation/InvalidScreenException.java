package com.tenzin.momento.sdui.validation;

import java.util.List;

public class InvalidScreenException extends RuntimeException {

    private final List<ValidationError> errors;

    public InvalidScreenException(List<ValidationError> errors) {
        super("Screen failed validation: " + errors);
        this.errors = List.copyOf(errors);
    }

    public List<ValidationError> errors() {
        return errors;
    }
}

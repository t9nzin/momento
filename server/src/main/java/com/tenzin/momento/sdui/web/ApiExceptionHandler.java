package com.tenzin.momento.sdui.web;

import com.tenzin.momento.sdui.item.ItemNotFoundException;
import com.tenzin.momento.sdui.screen.ScreenNotFoundException;
import com.tenzin.momento.sdui.validation.InvalidScreenException;
import org.springframework.http.HttpStatus;
import org.springframework.http.ProblemDetail;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;

/** Maps domain exceptions to RFC 7807 problem responses. */
@RestControllerAdvice
public class ApiExceptionHandler {

    @ExceptionHandler({ScreenNotFoundException.class, ItemNotFoundException.class})
    public ProblemDetail notFound(RuntimeException e) {
        return ProblemDetail.forStatusAndDetail(HttpStatus.NOT_FOUND, e.getMessage());
    }

    @ExceptionHandler(IllegalArgumentException.class)
    public ProblemDetail badRequest(IllegalArgumentException e) {
        return ProblemDetail.forStatusAndDetail(HttpStatus.BAD_REQUEST, e.getMessage());
    }

    /** A provider built a screen that breaks the contract. That is a server bug, not a client one. */
    @ExceptionHandler(InvalidScreenException.class)
    public ProblemDetail invalidScreen(InvalidScreenException e) {
        var problem = ProblemDetail.forStatusAndDetail(HttpStatus.INTERNAL_SERVER_ERROR, "Screen failed validation");
        problem.setProperty("errors", e.errors().stream().map(Object::toString).toList());
        return problem;
    }
}

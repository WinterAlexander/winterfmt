# winterfmt

Some Java code formatter for someone with very specific preferences. Some say it's best to stick to a popular standard, but I just didn't like the options there is for Java.

This formatter works by wrapping clang-format but avoids limitations of clang-format.

e.g. clang-format does not provide an option to keep the braces {} together when the body of the catch is empty.

```java
try {
    // some code
} catch(Exception ignored) {}
```

Feel free to make use of this repo as inspiration if you run into the same problem.

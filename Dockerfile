FROM dgtlmoon/changedetection.io:latest
EXPOSE 5000
CMD ["python3", "changedetection.py", "-p", "5000"]
1. Clone the repo from: https://github.com/ollama-webui/ollama-webui
2. Tweak the docker-compose to your liking
3. Run the container: 
    - 3.1. 
        ### For NVIDIA (default)
        docker-compose up
    - 3.2.
        ### For AMD
        GPU_DRIVER=amd docker-compose up
pipeline {
    agent any

    environment {
        VENV_DIR     = 'venv'
        GCP_PROJECT  = "learned-cosine-468917-e9"
        GCLOUD_PATH  = "/var/jenkins_home/google-cloud-sdk/bin"
        IMAGE_NAME   = "gcr.io/${GCP_PROJECT}/ml-project:latest"
    }

    stages {
        stage('Clone repo') {
            steps {
                echo 'Cloning GitHub repository...'
                checkout([
                    $class: 'GitSCM',
                    branches: [[name: '*/main']],
                    userRemoteConfigs: [[
                        credentialsId: 'github-token',
                        url: 'https://github.com/jeet-yadav27/MLOPS_Project.git'
                    ]]
                ])
            }
        }

        stage('Set up venv & install deps') {
            steps {
                echo 'Setting up Python virtual environment...'
                sh '''
                    python -m venv ${VENV_DIR}
                    . ${VENV_DIR}/bin/activate
                    pip install --upgrade pip
                    pip install -e .
                '''
            }
        }

        stage('Build & push Docker image') {
            steps {
                withCredentials([file(credentialsId: 'gcp-key', variable: 'GOOGLE_APPLICATION_CREDENTIALS')]) {
                    sh '''
                        export PATH=$PATH:${GCLOUD_PATH}
                        gcloud auth activate-service-account --key-file=${GOOGLE_APPLICATION_CREDENTIALS}
                        gcloud config set project ${GCP_PROJECT}
                        gcloud auth configure-docker --quiet

                        docker build -t ${IMAGE_NAME} .
                        docker push ${IMAGE_NAME}
                    '''
                }
            }
        }

        stage('Run pipeline in container') {
            steps {
                withCredentials([file(credentialsId: 'gcp-key', variable: 'GOOGLE_APPLICATION_CREDENTIALS')]) {
                    sh '''
                        echo "Running training pipeline inside container..."
                        docker run --rm \
                          -e GOOGLE_APPLICATION_CREDENTIALS=/app/sa.json \
                          -v ${GOOGLE_APPLICATION_CREDENTIALS}:/app/sa.json:ro \
                          ${IMAGE_NAME} bash -c "python pipeline/training_pipeline.py && python application.py"
                    '''
                }
            }
        }
    }
}

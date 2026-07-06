pipeline {
    agent any

    stages {

        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Validate Build') {
            steps {
                script {
                    echo "BRANCH_NAME=${env.BRANCH_NAME}"
                    echo "CHANGE_ID=${env.CHANGE_ID}"
                    echo "CHANGE_BRANCH=${env.CHANGE_BRANCH}"
                    echo "CHANGE_TARGET=${env.CHANGE_TARGET}"

                    if (env.CHANGE_ID) {
                        // PR build
                        if (env.CHANGE_TARGET == 'main') {
                            echo "Pull Request targeting main"
                        } else {
                            currentBuild.result = 'NOT_BUILT'
                            error("Build skipped. Pull requests must target 'main'.")
                        }
                    } else {
                        // Normal branch build
                        echo "Branch build: ${env.BRANCH_NAME}"
                    }
                }
            }
        }

        stage('Init Variables') {
            steps {
                script {
                    env.REMOTE_URL = sh(
                        script: "git config --get remote.origin.url",
                        returnStdout: true
                    ).trim()

                    env.ORG = sh(
                        script: "echo ${env.REMOTE_URL} | sed -E 's#https://github.com/([^/]+)/.*#\\1#'",
                        returnStdout: true
                    ).trim()

                    env.REPO = sh(
                        script: "echo ${env.REMOTE_URL} | sed -E 's#.*/([^/]+)\\.git#\\1#'",
                        returnStdout: true
                    ).trim()

                    env.TEMPLATE_REPO = "https://github.com/bit-template/tool-template.git"
                }
            }
        }

        stage('Template Version Sync') {

            when {
                allOf {
                    expression { env.CHANGE_ID != null }
                    expression { env.CHANGE_TARGET == 'main' }
                }
            }

            steps {
                script {

                    withCredentials([usernamePassword(
                        credentialsId: 'github-creds',
                        usernameVariable: 'ADMIN_USER',
                        passwordVariable: 'GITHUB_TOKEN'
                    )]) {

                        sh """
                            TEMPLATE_HASH=\$(git ls-remote https://\${ADMIN_USER}:\${GITHUB_TOKEN}@github.com/bit-template/tool-template.git HEAD | awk '{print \$1}')

                            CURRENT_HASH=""

                            if [ -f .template-sync-version ]; then
                                CURRENT_HASH=\$(cat .template-sync-version)
                            fi

                            echo "Current hash: \${CURRENT_HASH}"
                            echo "Template hash: \${TEMPLATE_HASH}"

                            if [ "\$CURRENT_HASH" = "\$TEMPLATE_HASH" ]; then
                                echo "Template unchanged. Skip sync."
                                exit 0
                            fi

                            echo "Template updated. Running sync..."

                            /opt/scripts/sync-template.sh \
                            ${env.REPO} \
                            ${env.ORG} \
                            ${env.TEMPLATE_REPO}

                            echo "\$TEMPLATE_HASH" > .template-sync-version

                            git add .template-sync-version

                            git commit -m "[skip ci] Update template sync version" || true

                            git push \
                            https://\${ADMIN_USER}:\${GITHUB_TOKEN}@github.com/${env.ORG}/${env.REPO}.git \
                            HEAD:main || true
                        """
                    }
                }
            }
        }

        stage('Init Repo Protection') {
            when {
                expression { fileExists('.jenkins/first-run.flag') }
            }

            steps {
                withCredentials([usernamePassword(
                    credentialsId: 'github-creds',
                    usernameVariable: 'ADMIN_USER',
                    passwordVariable: 'GITHUB_TOKEN'
                )]) {

                    sh """
                        /opt/scripts/gradlew-permission.sh ${env.REPO} ${env.ORG}
                        /opt/scripts/remove-flag.sh ${env.REPO} ${env.ORG}
                        /opt/scripts/branch-protection.sh ${env.REPO} ${env.ORG}
                    """
                }
            }
        }

        stage('Sandbox Test') {
            steps {
                sh './gradlew testSandbox'
            }
        }
    }

    post {
        always {
            emailext(
                subject: "Jenkins Job: ${env.JOB_NAME} #${env.BUILD_NUMBER} finished",
                body: """\
Build Status: ${currentBuild.currentResult}
Repository: ${env.REPO}
Organization: ${env.ORG}
Template Repo: ${env.TEMPLATE_REPO}
Build URL: ${env.BUILD_URL}
""",
                to: "bitresearch2006@gmail.com"
            )
        }
    }
}
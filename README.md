# tag-latest-environ-autodeploy

The current image can create a tag and a 'latest' label depending on the branches and SHA of the push commit. Additionally, based on its input, it can select the environment or "environ" that can be used for the rest of the GitHub action.

The parameter it can receive is "**validPush**", which is composed of tuples separated by spaces. The tuples are in the following format:

**name/environ/delivery**, where:

**name**: is in the form type:id, where "type" can be "branch" or "tag", the id in the case of a branch is the name of the branch, in the case of a tag, the beginning of the tag, for example, tag:rc for tags rc-0.1.3, rc-1.0.0, among others; tag:v for tags v-0.0.1, v-1.0.1, etc.
- **environ**: is the environment that will be returned when the push matches the previous "name".
- **delivery**: "auto" for RUN_CD true, "manual" for RUN_CD false.

If a "**validPush**" is not provided, the default is assumed, whose value is: _"branch-develop/develop/auto branch-staging/staging/auto tag-rc/release/auto tag-v/production/manual"_

## Example:

```yaml
name: example

env:
    repo: repository_url
    AWS_REGION: us-west-1
    DEPLOY: test
    NS: test

on:
  push:
    tags:
        - 'v-*'
    branches:
        - staging

jobs:
    check:
        name: check
        runs-on: ubuntu-latest
        outputs:
            TAG: ${{ steps.check-ref.outputs.TAG }}
            LATEST: ${{ steps.check-ref.outputs.LATEST }}
            ENV: ${{ steps.check-ref.outputs.ENVIRON }}
            RUN_CI: ${{ steps.check-ref.outputs.RUN_CI }}
            RUN_CD: ${{ steps.check-ref.outputs.RUN_CD }}
        steps:
          - name: Checkout
            uses: actions/checkout@v4

          - name: test git ref
            id: check-ref
            uses: RAcl/tag-latest-environ-autodeploy@v2
            with:
                validPush: "branch:staging/staging/auto tag:v/production/manual"

    integration:
        if: ${{ needs.check.outputs.RUN_CI == 'true' }}
        needs: check
        name: integration
        runs-on: ubuntu-latest
        outputs:
            IMAGE: ${{ steps.build-image.outputs.IMAGE }}
        steps:
          - name: Checkout
            uses: actions/checkout@v4
      
          - name: Configure AWS credentials
            uses: aws-actions/configure-aws-credentials@v4
            with:
              aws-access-key-id: ${{ vars.AWS_KEY_ID }}
              aws-secret-access-key: ${{ secrets.AWS_SECRET }}
              aws-region: ${{ env.AWS_REGION }}
      
          - name: Login to Amazon ECR
            id: login-ecr
            uses: aws-actions/amazon-ecr-login@v2
      
          - name: Build and push image to Amazon ECR
            id: build-image
            env:
              ECR_REGISTRY: ${{ steps.login-ecr.outputs.registry }}
              ECR_REPOSITORY: ${{ env.repo }}
              TAG: ${{ needs.check.outputs.TAG }}
              LATEST: ${{ needs.check.outputs.LATEST }}
              ENVIRON: ${{ needs.check.outputs.ENV }}
            run: |
              docker build -t $ECR_REPOSITORY \
                --build-arg="ENVIRON=${ENVIRON}" \
                .
              docker tag $ECR_REPOSITORY:latest $ECR_REGISTRY/$ECR_REPOSITORY:$LATEST
              docker tag $ECR_REPOSITORY:latest $ECR_REGISTRY/$ECR_REPOSITORY:$TAG
              docker push $ECR_REGISTRY/$ECR_REPOSITORY:$LATEST
              docker push $ECR_REGISTRY/$ECR_REPOSITORY:$TAG
              echo "IMAGE=$ECR_REGISTRY/$ECR_REPOSITORY:$TAG" >> $GITHUB_OUTPUT
              echo $ECR_REGISTRY/$ECR_REPOSITORY:$TAG

    delivery:
        if: ${{ needs.check.outputs.RUN_CD == 'true' }}
        needs: [check, integration]
        name: delivery
        runs-on: ubuntu-latest
        steps:
          - name: Deploy to EKS
            uses: RAcl/kube@main
            env:
              KUBE_CONFIG: ${{ secrets.KUBE_CONFIG_DATA }}
              AWS_ACCESS_KEY_ID: ${{ vars.AWS_KEY_ID }}
              AWS_SECRET_ACCESS_KEY: ${{ secrets.AWS_SECRET }}
              AWS_DEFAULT_REGION: ${{ env.AWS_REGION }}
              K8S_DEPLOY: ${{ env.DEPLOY }}
              K8S_NS: ${{ env.NS }}
              IMAGE: ${{ needs.integration.outputs.IMAGE }}
            with:
              args: set image deployment.apps/${K8S_DEPLOY} ${K8S_DEPLOY}=${IMAGE} -n ${K8S_NS}
      
          - name: Verify deploy on EKS
            uses: RAcl/kube@main
            env:
                KUBE_CONFIG: ${{ secrets.KUBE_CONFIG_DATA }}
                AWS_ACCESS_KEY_ID: ${{ vars.AWS_KEY_ID }}
                AWS_SECRET_ACCESS_KEY: ${{ secrets.AWS_SECRET }}
                AWS_DEFAULT_REGION: ${{ env.AWS_REGION }}
                K8S_DEPLOY: ${{ env.DEPLOY }}
                K8S_NS: ${{ env.NS }}
            with:
              args: rollout status deployment.apps/${K8S_DEPLOY} -n ${K8S_NS}

```

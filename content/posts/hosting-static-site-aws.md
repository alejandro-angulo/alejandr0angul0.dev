+++
title = "Hosting a Static Site on AWS"
date = "2020-07-17T12:31:32-07:00"
author = "alejandro"
tags = ["info-dump"]
keywords = ["AWS", "S3", "CloudFront", "Route 53", "Hugo"]
showFullContent = false
+++

I bought a domain name on a whim recently and felt like I had to justify my purchase by building a site to make use of it. In a
past life I might have used WordPress or Django but I was feeling especially lazy. At first I was going to use GitHub Pages but
that seemed too easy. I haven't really touched AWS before and I felt like I might as well make this into a learning opportunity.
As you can probably tell by the title, I ended up using AWS to host a static site. This post documents the steps I took to get
this working. These steps were compiled after I had everything working so it's possible there may be some typos. If you stumbled
upon this and have a question on a step, feel free to reach out (you can find my contact info on the [about
page](/about#contact)).

## Configuring AWS CLI

Log on to the AWS console and create an IAM user with administrator access. Keep the user's credentials safe since this user has
full access to your AWS account. Install the aws cli utility and run `aws configure` and use the admin user's credentials that
were just generated. It's not necessary but I also went ahead and set my region to `us-east-1`.

## Setting up S3 Bucket

I didn't already have an AWS account (or at least not one that I had the password to) so I fired up `https://aws.amazon.com/` and
created an account. From there, I went to [the AWS console](https://s3.console.aws.amazon.com/) and created a new bucket with the
same name as my domain name (this part is important). So if your domain name is `supercool.tld` your bucket name would also be
`supercool.tld`. Once the bucket is created, static website hosting needs to be enabled. Set the index document value to
`index.html` even though there's nothing in the bucket yet.

An S3 bucket is used to house the site's static files.

```bash
aws s3 mb s3://<your domain name here>
```

The bucket also has to be configured for static website hosting and the files should be public. Prepare a json file to give anyone
read permissions to objects in the bucket.

```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": "*",
            "Action": "s3:GetObject",
            "Resource": "arn:aws:s3:::<your domain name here>/*"
        }
    ]
}
```

```bash
aws s3api put-bucket-policy --bucket <your domain name here> --policy file://<path to json file>
aws s3 website s3://<your domain name here> --index-document index.html
```

## Setting up Route 53

Create a hosted zone in AWS. A hosted zone contains the configuration (A records, CNAME, records, etc.) for a domain.

```bash
aws route53 create-hosted-zone --name <your domain name here> --caller-reference $(date -Ins)
```

Caller reference just needs to be a unique string so we use the current datetime (with nanosecond precision). Now that a hosted
zone is setup, we'll need to get it's zone ID so we can set up a certificate.

```bash
aws route53 list-hosted-zones
```

## Setting up Certificate

A cerificate is needed for https support. To do so a cert has to be requeted from AWS's aptly named AWS Certificate Manager (ACM).
Once  a request is in, domain ownership needs to be validated (AWS can't be giving out certs for just any domain). Validation can
be done through DNS or email. Email validation requires controlling an email address like `admin@suprecool.tld` and clicking a
link in an email sent to it. DNS validation requires adding a CNAME record in a hosted zone.

ACM certs are automatically renewed as long as the domain validation does not expire. Email validation has to be revalidated every
825 days (about every two years). For DNS validation, this just means leaving the CNAME record up. DNS validation is a bit more
straightforward so we'll use that. Run the following command and make note of the ARN, it'll be needed later.

```bash
aws acm request-certificate --domain-name <your domain name here> --validation-method DNS
```

ACM will provide the CNAME data expected for validation. Run the command below and look at `DomainValidationOptions` for the
expected values.

```bash
aws acm describe-certificate --certificate-arn <arn from previous command>
```

Prepare a json file to add the required CNAME.

```json
{
    "Changes": [{
        "Action": "CREATE",
        "ResourceRecordSet": {
            "Name": "<name shown in last command>",
            "Type": "CNAME",
            "TTL": 300,
            "ResourceRecords": [{
                "Value": "<value show in last command>"
            }]
        }
    }]
}
```

```bash
aws route53 change-resource-record-sets --hosted-zone-id <your hosted zone ID> --change-batch-file file://<path to/gc json file here>
```

It'll take a bit for ACM to validate your new CNAME record. But once it's validated you'll be able to see the certificate by
running the following:

```bash
aws acm get-certificate --certificate-arn <your cert arn here>
```

## Setting up CloudFront

Since S3 website endpoints don't support HTTPS, we'll configure CloudFront (AWS's CDN service) to serve up our files. The template
for the JSON required is below. The region name is whatever was configured when `aws configure` was ran earlier.

{{<code language="json">}}
{
    "Aliases": {
        "Quantity": 1,
        "Items": [
            "<your domain name here>"
        ]
    },
    "DefaultRootObject": "index.html",
    "Origins": {
        "Quantity": 1,
        "Items": [
            {
                "Id": "S3-Website-<your domain name here>.s3-website-<your region here>.amazonaws.com",
                "DomainName": "<your domain name here>.s3-website-<your region here>.amazonaws.com",
                "OriginPath": "",
                "CustomHeaders": {
                    "Quantity": 0
                },
                "CustomOriginConfig": {
                    "HTTPPort": 80,
                    "HTTPSPort": 443,
                    "OriginProtocolPolicy": "http-only",
                    "OriginSslProtocols": {
                        "Quantity": 3,
                        "Items": [
                            "TLSv1",
                            "TLSv1.1",
                            "TLSv1.2"
                        ]
                    },
                    "OriginReadTimeout": 30,
                    "OriginKeepaliveTimeout": 5
                },
                "ConnectionAttempts": 3,
                "ConnectionTimeout": 10
            }
        ]
    },
    "OriginGroups": {
        "Quantity": 0
    },
    "DefaultCacheBehavior": {
        "TargetOriginId": "S3-Website-<your domain name here>.s3-website-<your region here>.amazonaws.com",
        "ForwardedValues": {
            "QueryString": false,
            "Cookies": {
                "Forward": "none"
            },
            "Headers": {
                "Quantity": 0
            },
            "QueryStringCacheKeys": {
                "Quantity": 0
            }
        },
        "TrustedSigners": {
            "Enabled": false,
            "Quantity": 0
        },
        "ViewerProtocolPolicy": "redirect-to-https",
        "MinTTL": 0,
        "AllowedMethods": {
            "Quantity": 2,
            "Items": [
                "HEAD",
                "GET"
            ],
            "CachedMethods": {
                "Quantity": 2,
                "Items": [
                    "HEAD",
                    "GET"
                ]
            }
        },
        "SmoothStreaming": false,
        "DefaultTTL": 86400,
        "MaxTTL": 31536000,
        "Compress": false,
        "LambdaFunctionAssociations": {
            "Quantity": 0
        },
        "FieldLevelEncryptionId": ""
    },
    "CacheBehaviors": {
        "Quantity": 0
    },
    "CustomErrorResponses": {
        "Quantity": 1,
        "Items": [
            {
                "ErrorCode": 404,
                "ResponsePagePath": "/404.html",
                "ResponseCode": "404",
                "ErrorCachingMinTTL": 60
            }
        ]
    },
    "Comment": "",
    "Logging": {
        "Enabled": false,
        "IncludeCookies": false,
        "Bucket": "",
        "Prefix": ""
    },
    "PriceClass": "PriceClass_All",
    "Enabled": true,
    "ViewerCertificate": {
        "ACMCertificateArn": "<your certificate ARN>",
        "SSLSupportMethod": "sni-only",
        "MinimumProtocolVersion": "TLSv1.2_2018",
        "Certificate": "<your certificate ARN>",
        "CertificateSource": "acm"
    },
    "Restrictions": {
        "GeoRestriction": {
            "RestrictionType": "none",
            "Quantity": 0
        }
    },
    "WebACLId": "",
    "HttpVersion": "http2",
    "IsIPV6Enabled": true
}
{{</code>}}

```bash
aws create-distribution --distribution-config file://<path to/gc json file>
```

## Finish Setting up Route 53

Now that that CloudFront is configured we can add an A record to our DNS config. Prepare a JSON file for the request. Make sure to
include the trailing `.` for the `Name` and `DNSName` values. Speaking of `DNSName`, run the following to get the CloudFront
distribution's domain name:

```bash
aws cloudfront list-distributions | grep DomainName | head -n1
```

The above command only works correctly if you only have one CloudFront distribution configured in your account. If you have more
than one distribution, log in to the AWS console and grab the domain name from the distribution that way.

Prepare a json file for the Route 53 request. Fun fact: `HostedZoneId` is hardcoded for CloudFront distributions.

```json
{
    "Changes": [{
        "Action": "CREATE",
        "ResourceRecordSet": {
            "Name": "<your domain name here>.",
            "Type": "A",
            "AliasTarget": {
                "HostedZoneId": "Z2FDTNDATAQYW2",
                "DNSName": "<your CloudFront distribution domain name>.",
                "EvaluateTargetHealth": false
            }
        }
    }]
}
```

```bash
aws route53 change-resource-record-sets --hosted-zone-id <your hosted zone ID> --change-batch-file file://<path to/gc json file here>
```

## Upload Files

Everything should be ready now, we just need to add some files. Create a sample index file and uptload it to test.

```html
<h1>It works!</h1>
```

Let's also create a sample 404 error page file.

```html
<h1>Page does not exist</h1>
```

```bash
aws s3 cp <path to sample index file> s3://<your domain name>/index.html
aws s3 cp <path to sample 404 file> s3://<your domain name>/404.html
```

Fire up your site and cross your fingers. If all went well you should see the `It works!` message when you point your broweser to
your URL and a page does not exist message when you try accessing something like `<your domain name here>/foo`.


# iOS Signing Notes

The user provided an enterprise signing archive at:

`C:/Users/liu/Desktop/证书_00008120-00064D6C1A98201E.zip`

Do not commit this archive, the `.p12`, the `.mobileprovision`, or the password file to Git.

## Non-sensitive Profile Metadata

- Certificate archive contents: `证书文件.p12`, `描述文件.mobileprovision`, `密码.txt`
- Team ID: `T9D6U74H9U`
- Bundle ID: `app.calcite4884.lyra3161`
- Profile UUID: `d6963832-1597-4156-ba23-e0cc7ee4861e`
- Profile expiration: `2027-06-16 20:22:12`
- Provisioned devices: yes

## Codemagic Setup

Upload these files in Codemagic team settings under code signing identities:

1. Upload `证书文件.p12` as an iOS certificate and enter the password from `密码.txt`.
2. Upload `描述文件.mobileprovision` as an iOS provisioning profile.
3. Use the Bundle ID `app.calcite4884.lyra3161`.

The project `codemagic.yaml` is configured with:

```yaml
environment:
  ios_signing:
    distribution_type: enterprise
    bundle_identifier: app.calcite4884.lyra3161
```

Codemagic should fetch matching signing assets and run `xcode-project use-profiles` during the build.
